use std::pin::Pin;

use rustler::types::binary::{Binary, OwnedBinary};
use rustler::types::tuple::make_tuple;
use rustler::types::{Encoder, LocalPid};
use rustler::{Atom, Env, NifResult, ResourceArc};

use crate::common::{self, atoms};
use crate::socket::Peer;

macro_rules! empty_vec {
    ($x:expr) => {
        unsafe {
            let mut v = Vec::with_capacity($x);
            v.set_len($x);
            v
        }
    };
}

pub struct Connection {
    raw: Pin<Box<quiche::Connection>>,
    peer: ResourceArc<Peer>,
    sender: LocalPid,
    dgram_buf: Vec<u8>,
    stream_buf: Vec<u8>,
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
            dgram_buf: empty_vec!(1500),
            stream_buf: empty_vec!(default_stream_buf_size),
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
            match self.raw.recv(packet) {
                Ok(_len) => {
                    self.handle_stream(env, pid);
                    self.handle_dgram(env, pid);
                    self.drain(env);
                    self.next_timeout()
                }
                Err(_e) => Err(atoms::system_error()),
            }
        } else {
            Err(atoms::already_closed())
        }
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

    pub fn send_stream_data(
        &mut self,
        env: &Env,
        stream_id: u64,
        data: &[u8],
    ) -> Result<u64, Atom> {
        let size = data.len();
        if !self.raw.is_closed() {
            let mut pos = 0;
            loop {
                match self.raw.stream_send(stream_id, &data[pos..], true) {
                    Ok(len) => {
                        pos += len;
                        self.drain(env);
                        if pos >= size {
                            break;
                        }
                    }

                    Err(quiche::Error::Done) => {
                        break;
                    }

                    Err(_e) => {
                        return Err(atoms::system_error());
                    }
                }
            }
            self.next_timeout()
        } else {
            Err(atoms::already_closed())
        }
    }

    pub fn send_dgram(&mut self, env: &Env, data: &[u8]) -> Result<u64, Atom> {
        if !self.raw.is_closed() {
            match self.raw.dgram_send(data) {
                Ok(()) => {
                    self.drain(env);
                    self.next_timeout()
                }
                Err(_e) => Err(atoms::system_error()),
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

    fn handle_stream(&mut self, env: &Env, pid: &LocalPid) {
        if self.raw.is_in_early_data() || self.raw.is_established() {
            for sid in self.raw.readable() {
                while let Ok((len, _fin)) = self.raw.stream_recv(sid, &mut self.stream_buf) {
                    if len > 0 {
                        let mut data = OwnedBinary::new(len).unwrap();
                        data.as_mut_slice().copy_from_slice(&self.stream_buf[..len]);
                        env.send(
                            pid,
                            make_tuple(
                                *env,
                                &[
                                    atoms::__stream_recv__().to_term(*env),
                                    sid.encode(*env),
                                    data.release(*env).to_term(*env),
                                ],
                            ),
                        );
                    }
                }
            }
        }
    }

    fn handle_dgram(&mut self, env: &Env, pid: &LocalPid) {
        if self.raw.is_in_early_data() || self.raw.is_established() {
            while let Ok(len) = self.raw.dgram_recv(&mut self.dgram_buf) {
                if len > 0 {
                    let mut data = OwnedBinary::new(len).unwrap();
                    data.as_mut_slice().copy_from_slice(&self.dgram_buf[..len]);

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
        }
    }

    fn drain(&mut self, env: &Env) {
        loop {
            match self.raw.send(&mut self.dgram_buf) {
                Ok(len) => {
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

    match quiche::accept(&scid, Some(&odcid), conf) {
        Ok(raw_conn) => {
            let conn = Connection::new(raw_conn, peer, sender_pid, stream_buf_size as usize);
            Ok((atoms::ok(), Box::into_raw(Box::new(conn)) as i64))
        }

        Err(_) => Err(common::error_term(atoms::system_error())),
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

    match conn.process_packet(&env, &pid, &mut packet.as_mut_slice()) {
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
pub fn connection_stream_send(
    env: Env,
    conn_ptr: i64,
    stream_id: u64,
    data: Binary,
) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };

    match conn.send_stream_data(&env, stream_id, data.as_slice()) {
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
