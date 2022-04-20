use std::cell::RefCell;
use std::pin::Pin;
use std::rc::Rc;

use rustler::types::binary::{Binary, OwnedBinary};
use rustler::types::tuple::make_tuple;
use rustler::types::{Encoder, LocalPid};
use rustler::{Atom, Env, NifResult, ResourceArc};

use crate::common::{self, atoms};
use crate::socket::Peer;
use quiche::h3::webtransport::{Error, ServerEvent, ServerSession};

pub struct Connection {
    raw: Pin<Box<quiche::Connection>>,
    peer: ResourceArc<Peer>,
    sender: LocalPid,
    dgram_buf: Vec<u8>,
    stream_buf: Vec<u8>,
    webtransport: Option<Rc<RefCell<ServerSession>>>,
    is_established: bool,
}

impl Connection {
    pub fn new(
        raw: Pin<Box<quiche::Connection>>,
        peer: ResourceArc<Peer>,
        sender: LocalPid,
        default_stream_buf_size: usize,
    ) -> Self {
        Self {
            raw,
            peer,
            sender,
            dgram_buf: vec![0; 1500],
            stream_buf: vec![0; default_stream_buf_size],
            webtransport: None,
            is_established: false,
        }
    }

    pub fn initialize_webtransport(&mut self) -> Result<(), Atom> {
        match ServerSession::with_transport(&mut self.raw) {
            Ok(server) => {
                self.webtransport = Some(Rc::new(RefCell::new(server)));
                Ok(())
            }
            Err(e) => {
                error!("failed to initialize webtransport: {:?}", e);
                Err(atoms::system_error())
            }
        }
    }

    pub fn is_closed(&self) -> bool {
        self.raw.is_closed()
    }

    pub fn process_packet(
        &mut self,
        env: &Env,
        pid: &LocalPid,
        packet: &mut [u8],
    ) -> Result<u64, Atom> {
        if !self.raw.is_closed() {
            let info = quiche::RecvInfo {
                from: self.peer.addr,
            };
            match self.raw.recv(packet, info) {
                Ok(_len) => {
                    if !self.is_established && self.raw.is_established() {
                        info!("established QUIC connection, initialize webtransport.");
                        self.is_established = true;
                        self.initialize_webtransport()?;
                    }
                    self.poll_webtransport_events(env, pid)?;
                    self.drain(env);
                    self.next_timeout()
                }
                Err(e) => {
                    error!("failed to conn.recv: {:?}", e);
                    Err(atoms::system_error())
                }
            }
        } else {
            Err(atoms::already_closed())
        }
    }

    pub fn accept_connect_request(&mut self, env: &Env) -> Result<u64, Atom> {
        if let Some(transport) = &self.webtransport {
            debug!("webtransport.accept_connect_request");
            // TODO more extra headers
            let result = transport
                .borrow_mut()
                .accept_connect_request(&mut self.raw, None);
            match result {
                Ok(()) => {
                    self.drain(env);
                    self.next_timeout()
                }
                Err(e) => {
                    error!("failed to webtransport.accept_connect_request: {:?}", e);
                    Err(atoms::system_error())
                }
            }
        } else {
            error!("invalid state: don't call this method before initialize webtransport");
            Err(atoms::system_error())
        }
    }

    pub fn reject_connect_request(&mut self, env: &Env, code: u32) -> Result<u64, Atom> {
        if let Some(transport) = &self.webtransport {
            debug!("webtransport.reject_connect_request");
            // TODO more extra headers
            let result = transport
                .borrow_mut()
                .reject_connect_request(&mut self.raw, code, None);
            match result {
                Ok(()) => {
                    self.drain(env);
                    self.next_timeout()
                }
                Err(e) => {
                    error!("failed to webtransport.reject_connect_request: {:?}", e);
                    Err(atoms::system_error())
                }
            }
        } else {
            error!("invalid state: don't call this method before initialize webtransport");
            Err(atoms::system_error())
        }
    }

    pub fn poll_webtransport_events(&mut self, env: &Env, pid: &LocalPid) -> Result<(), Atom> {
        if let Some(transport) = &self.webtransport {
            loop {
                let mut t = transport.borrow_mut();
                match t.poll(&mut self.raw) {
                    Ok(ServerEvent::ConnectRequest(req)) => {
                        let mut authority = OwnedBinary::new(req.authority().len()).unwrap();
                        authority
                            .as_mut_slice()
                            .copy_from_slice(req.authority().as_ref());

                        let mut path = OwnedBinary::new(req.path().len()).unwrap();
                        path.as_mut_slice().copy_from_slice(req.path().as_ref());

                        let mut origin = OwnedBinary::new(req.origin().len()).unwrap();
                        origin.as_mut_slice().copy_from_slice(req.origin().as_ref());

                        env.send(
                            pid,
                            make_tuple(
                                *env,
                                &[
                                    atoms::__connect__().to_term(*env),
                                    authority.release(*env).to_term(*env),
                                    path.release(*env).to_term(*env),
                                    origin.release(*env).to_term(*env),
                                ],
                            ),
                        );
                    }
                    Ok(ServerEvent::StreamData(stream_id)) => {
                        while let Ok(len) =
                            t.recv_stream_data(&mut self.raw, stream_id, &mut self.stream_buf)
                        {
                            if len > 0 {
                                let mut data = OwnedBinary::new(len).unwrap();
                                data.as_mut_slice().copy_from_slice(&self.stream_buf[..len]);
                                env.send(
                                    pid,
                                    make_tuple(
                                        *env,
                                        &[
                                            atoms::__stream_recv__().to_term(*env),
                                            stream_id.encode(*env),
                                            data.release(*env).to_term(*env),
                                        ],
                                    ),
                                );
                            }
                        }
                    }
                    Ok(ServerEvent::Datagram) => loop {
                        match t.recv_dgram(&mut self.raw, &mut self.dgram_buf) {
                            Ok((in_session, offset, total_len)) => if in_session {
                                let len = total_len - offset;
                                if len > 0 {
                                    let mut data = OwnedBinary::new(len).unwrap();
                                    data.as_mut_slice()
                                        .copy_from_slice(&self.dgram_buf[offset..total_len]);

                                    env.send(
                                        pid,
                                        make_tuple(
                                            *env,
                                            &[
                                                atoms::__dgram_recv__().to_term(*env),
                                                data.release(*env).to_term(*env),
                                            ],
                                        ),
                                    );
                                }
                            }
                            Err(Error::Done) => break,
                            Err(e) => {
                                error!("failed to receive dgram: {:?}", e);
                                return Err(atoms::system_error());
                            }
                        }
                    },
                    Ok(ServerEvent::SessionReset(_e)) => {
                        env.send(pid, atoms::__reset__().to_term(*env));
                    }
                    Ok(ServerEvent::SessionFinished) => {
                        env.send(pid, atoms::__session_finished__().to_term(*env));
                    }
                    Ok(ServerEvent::StreamFinished(stream_id)) => {
                        env.send(
                            pid,
                            make_tuple(
                                *env,
                                &[
                                    atoms::__stream_finished__().to_term(*env),
                                    stream_id.encode(*env),
                                ],
                            ),
                        );
                    }
                    Ok(ServerEvent::SessionGoAway) => {
                        env.send(pid, atoms::__goaway__().to_term(*env));
                    }
                    Ok(ServerEvent::Other(sid, ev)) => {
                        debug!("an event which is not related to WebTransport: stream_id({}), event({:?})", sid, ev);
                    }
                    Err(Error::Done) => break,
                    Err(e) => {
                        error!("poll http3 event caught error: :{:?}", e);
                        return Err(atoms::system_error());
                    }
                }
            }
        }
        Ok(())
    }

    pub fn execute_timeout(&mut self, env: &Env) -> Result<u64, Atom> {
        if !self.raw.is_closed() {
            self.raw.on_timeout();
            self.drain(env);
            self.next_timeout()
        } else {
            Err(atoms::already_closed())
        }
    }

    pub fn open_stream(&mut self, env: &Env, is_bidi: bool) -> Result<(u64, u64), Atom> {
        if !self.raw.is_closed() {
            if let Some(transport) = &self.webtransport {
                let transport = Rc::clone(transport);
                let mut transport = transport.borrow_mut();
                match transport.open_stream(&mut self.raw, is_bidi) {
                    Ok(stream_id) => {
                        info!("opened new stream with stream-id: {}", stream_id);
                        self.drain(env);
                        self.next_timeout()
                            .map(|next_timeout| (stream_id, next_timeout))
                    }
                    Err(e) => {
                        error!("failed to open stream: {:?}", e);
                        Err(atoms::system_error())
                    }
                }
            } else {
                // TODO better error atom
                Err(atoms::system_error())
            }
        } else {
            Err(atoms::already_closed())
        }
    }

    pub fn send_stream_data(
        &mut self,
        env: &Env,
        stream_id: u64,
        data: &[u8],
        fin: bool,
    ) -> Result<u64, Atom> {
        let size = data.len();
        if !self.raw.is_closed() {
            if let Some(transport) = &self.webtransport {
                let transport = Rc::clone(transport);
                let mut pos = 0;
                loop {
                    match transport
                        .borrow_mut()
                        .send_stream_data(&mut self.raw, stream_id, data)
                    {
                        Ok(len) => {
                            pos += len;
                            self.drain(env);
                            if pos >= size {
                                break;
                            }
                        }
                        Err(Error::Done) => break,
                        Err(e) => {
                            error!("failed to send stream data: {:?}", e);
                            return Err(atoms::system_error());
                        }
                    }
                }
                if fin {
                    let _ = self.raw.stream_send(stream_id, b"", true);
                }
                self.next_timeout()
            } else {
                // TODO better error atom
                Err(atoms::system_error())
            }
        } else {
            Err(atoms::already_closed())
        }
    }

    pub fn send_dgram(&mut self, env: &Env, data: &[u8]) -> Result<u64, Atom> {
        if !self.raw.is_closed() {
            if let Some(transport) = &self.webtransport {
                let transport = Rc::clone(transport);
                let mut transport = transport.borrow_mut();
                match transport.send_dgram(&mut self.raw, data) {
                    Ok(()) => {
                        self.drain(env);
                        self.next_timeout()
                    }
                    Err(_e) => Err(atoms::system_error()),
                }
            } else {
                // TODO better error atom
                Err(atoms::system_error())
            }
        } else {
            Err(atoms::already_closed())
        }
    }

    pub fn close(&mut self, env: &Env, app: bool, err: u64, reason: &[u8]) -> Result<u64, Atom> {
        if !self.raw.is_closed() {
            match self.raw.close(app, err, reason) {
                Ok(()) => {
                    self.drain(env);
                    self.next_timeout()
                }

                Err(quiche::Error::Done) => self.next_timeout(),

                Err(_e) => Err(atoms::system_error()),
            }
        } else {
            Err(atoms::already_closed())
        }
    }

    fn drain(&mut self, env: &Env) {
        loop {
            match self.raw.send(&mut self.dgram_buf) {
                Ok((len, _send_info)) => {
                    let mut packet = OwnedBinary::new(len).unwrap();
                    packet
                        .as_mut_slice()
                        .copy_from_slice(&self.dgram_buf[..len]);
                    env.send(
                        &self.sender,
                        make_tuple(
                            *env,
                            &[
                                atoms::__drain__().to_term(*env),
                                self.peer.encode(*env),
                                packet.release(*env).to_term(*env),
                            ],
                        ),
                    );
                }
                Err(quiche::Error::Done) => {
                    break;
                }
                Err(_e) => {
                    self.raw.close(false, 0x1, b"fail").ok();
                    break;
                }
            }
        }
    }

    fn next_timeout(&mut self) -> Result<u64, Atom> {
        if let Some(timeout) = self.raw.timeout() {
            let to: u64 = timeout.as_millis() as u64;
            Ok(to)
        } else if self.raw.is_closed() {
            Err(atoms::already_closed())
        } else {
            // unreachable if 'idle_timeout' is set
            Ok(60000)
        }
    }
}

#[rustler::nif]
pub fn connection_accept(
    conf_ptr: i64,
    scid: Binary,
    odcid: Binary,
    peer: ResourceArc<Peer>,
    sender_pid: LocalPid,
    stream_buf_size: u64,
) -> NifResult<(Atom, i64)> {
    let scid = scid.as_slice();
    let odcid = odcid.as_slice();

    let conf_ptr = conf_ptr as *mut quiche::Config;
    let conf = unsafe { &mut *conf_ptr };

    let scid = quiche::ConnectionId::from_ref(scid);
    let odcid = quiche::ConnectionId::from_ref(odcid);

    match quiche::accept(&scid, Some(&odcid), peer.addr, conf) {
        Ok(raw_conn) => {
            let conn = Connection::new(raw_conn, peer, sender_pid, stream_buf_size as usize);
            Ok((atoms::ok(), Box::into_raw(Box::new(conn)) as i64))
        }

        Err(_) => Err(common::error_term(atoms::system_error())),
    }
}

#[rustler::nif]
pub fn connection_accept_connect_request(env: Env, conn_ptr: i64) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };
    match conn.accept_connect_request(&env) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_reject_connect_request(
    env: Env,
    conn_ptr: i64,
    code: u32,
) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };
    match conn.reject_connect_request(&env, code) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_destroy(conn_ptr: i64) -> NifResult<Atom> {
    let conn_ptr = conn_ptr as *mut Connection;
    unsafe { drop(Box::from_raw(conn_ptr)) };
    Ok(atoms::ok())
}

#[rustler::nif]
pub fn connection_close(
    env: Env,
    conn_ptr: i64,
    app: bool,
    err: u64,
    reason: Binary,
) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };

    match conn.close(&env, app, err, reason.as_slice()) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_is_closed(conn_ptr: i64) -> bool {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };
    conn.is_closed()
}

#[rustler::nif]
pub fn connection_on_packet(
    env: Env,
    pid: LocalPid,
    conn_ptr: i64,
    packet: Binary,
) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };

    let mut packet = packet.to_owned().unwrap();

    match conn.process_packet(&env, &pid, packet.as_mut_slice()) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_on_timeout(env: Env, conn_ptr: i64) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };

    match conn.execute_timeout(&env) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_open_stream(
    env: Env,
    conn_ptr: i64,
    is_bidi: bool,
) -> NifResult<(Atom, u64, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };

    match conn.open_stream(&env, is_bidi) {
        Ok((stream_id, next_timeout)) => {
            debug!(
                "open_stream returns stream_id:{}, next_timeout:{}",
                stream_id, next_timeout
            );
            Ok((atoms::ok(), stream_id, next_timeout))
        }
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_stream_send(
    env: Env,
    conn_ptr: i64,
    stream_id: u64,
    data: Binary,
    fin: bool,
) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };

    match conn.send_stream_data(&env, stream_id, data.as_slice(), fin) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_dgram_send(env: Env, conn_ptr: i64, data: Binary) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };
    match conn.send_dgram(&env, data.as_slice()) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}
