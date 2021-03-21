use rustler::types::binary::{Binary, OwnedBinary};
use rustler::types::tuple::make_tuple;
use rustler::types::{Encoder, LocalPid};
use rustler::{Atom, Env, NifResult, ResourceArc};

use once_cell::sync::Lazy;
use parking_lot::{Mutex, RwLock};

use std::convert::TryFrom;
use std::pin::Pin;

use std::collections::HashMap;

use crate::common::{self, atoms};
use crate::socket::{self, Peer};

type ModuleName = Vec<u8>;
type BufferSlot = Vec<Mutex<Box<[u8]>>>;
type StreamDataBuffer = RwLock<HashMap<ModuleName, BufferSlot>>;

static STREAM_DATA_BUFFERS: Lazy<StreamDataBuffer> = Lazy::new(|| RwLock::new(HashMap::new()));

pub fn buffer_init(module: &[u8], num: u64, size: usize) {
    let mut buffer_table = STREAM_DATA_BUFFERS.write();
    if !buffer_table.contains_key(module) {
        let mut slot = Vec::new();
        for _ in 0..num {
            let v = unsafe {
                let mut v: Vec<u8> = Vec::with_capacity(size);
                v.set_len(size);
                v
            };
            slot.push(Mutex::new(v.into_boxed_slice()));
        }
        buffer_table.insert(module.to_vec(), slot);
    }
}

pub struct Connection {
    module: Vec<u8>,
    conn: Pin<Box<quiche::Connection>>,
    peer: ResourceArc<Peer>,
    buf: [u8; 1350],
}

impl Connection {
    pub fn new(module: &[u8], conn: Pin<Box<quiche::Connection>>, peer: ResourceArc<Peer>) -> Self {
        Connection {
            module: module.to_vec(),
            conn,
            peer,
            buf: [0; 1350],
        }
    }

    pub fn on_packet(&mut self, env: &Env, pid: &LocalPid, packet: &mut [u8]) -> Result<u64, Atom> {
        if !self.conn.is_closed() {
            match self.conn.recv(packet) {
                Ok(_len) => {
                    self.handle_stream(env, pid);
                    self.handle_dgram(env, pid);
                    self.drain();
                    Ok(self.next_timeout())
                }

                Err(_) => Err(atoms::system_error()),
            }
        } else {
            Err(atoms::already_closed())
        }
    }

    fn next_timeout(&mut self) -> u64 {
        if let Some(timeout) = self.conn.timeout() {
            let to: u64 = TryFrom::try_from(timeout.as_millis()).unwrap();
            to
        } else {
            60000
        }
    }

    fn handle_stream(&mut self, env: &Env, pid: &LocalPid) {
        if self.conn.is_in_early_data() || self.conn.is_established() {
            let buffer_table = STREAM_DATA_BUFFERS.read();

            if let Some(buf) = buffer_table.get(&self.module) {
                // mitigate lock-wait
                let mut buf = buf[common::random_slot_index(buf.len())].lock();

                for s in self.conn.readable() {
                    while let Ok((len, _fin)) = self.conn.stream_recv(s, &mut buf) {
                        if len > 0 {
                            let mut data = OwnedBinary::new(len).unwrap();
                            data.as_mut_slice().copy_from_slice(&buf[..len]);

                            env.send(
                                pid,
                                make_tuple(
                                    *env,
                                    &[
                                        atoms::__stream_recv__().to_term(*env),
                                        s.encode(*env),
                                        data.release(*env).to_term(*env),
                                    ],
                                ),
                            )
                        }
                    }
                }
            }
        }
    }

    fn stream_send(&mut self, stream_id: u64, data: &[u8]) -> Result<u64, Atom> {
        let size = data.len();

        if !self.conn.is_closed() {
            let mut pos = 0;
            loop {
                match self.conn.stream_send(stream_id, &data[pos..], true) {
                    Ok(len) => {
                        pos += len;
                        self.drain();
                        if pos >= size {
                            break;
                        }
                    }
                    Err(quiche::Error::Done) => {
                        break;
                    }
                    Err(_) => {
                        return Err(atoms::system_error());
                    }
                };
            }

            Ok(self.next_timeout())
        } else {
            Err(atoms::already_closed())
        }
    }

    fn dgram_send(&mut self, data: &[u8]) -> Result<u64, Atom> {
        if !self.conn.is_closed() {
            match self.conn.dgram_send(data) {
                Ok(()) => {
                    self.drain();
                    Ok(self.next_timeout())
                }

                Err(_) => Err(atoms::system_error()),
            }
        } else {
            Err(atoms::already_closed())
        }
    }

    fn handle_dgram(&mut self, env: &Env, pid: &LocalPid) {
        if self.conn.is_in_early_data() || self.conn.is_established() {
            while let Ok(len) = self.conn.dgram_recv(&mut self.buf) {
                if len > 0 {
                    let mut data = OwnedBinary::new(len).unwrap();
                    data.as_mut_slice().copy_from_slice(&self.buf[..len]);

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

    pub fn on_timeout(&mut self) -> Result<u64, Atom> {
        if !self.conn.is_closed() {
            self.conn.on_timeout();
            self.drain();
            Ok(self.next_timeout())
        } else {
            Err(atoms::already_closed())
        }
    }

    pub fn is_closed(&self) -> bool {
        self.conn.is_closed()
    }

    pub fn close(&mut self, app: bool, err: u64, reason: &[u8]) -> Result<(), Atom> {
        if !self.conn.is_closed() {
            match self.conn.close(app, err, reason) {
                Ok(()) => {
                    self.drain();
                    Ok(())
                }

                Err(quiche::Error::Done) => Ok(()),

                Err(_) => Err(atoms::system_error()),
            }
        } else {
            Err(atoms::already_closed())
        }
    }

    fn drain(&mut self) {
        loop {
            match self.conn.send(&mut self.buf) {
                Ok(len) => {
                    match socket::send_internal(&self.module, &self.peer, &self.buf[..len]) {
                        Ok(()) => {}
                        Err(_) => {
                            continue;
                        }
                    }
                }

                Err(quiche::Error::Done) => {
                    break;
                }

                Err(_) => {
                    // XXX should return error?
                    self.conn.close(false, 0x1, b"fail").ok();
                    break;
                }
            };
        }
    }
}

#[rustler::nif]
pub fn connection_accept(
    module: Binary,
    conf_ptr: i64,
    scid: Binary,
    odcid: Binary,
    peer: ResourceArc<Peer>,
) -> NifResult<(Atom, i64)> {
    let module = module.as_slice();
    let scid = scid.as_slice();
    let odcid = odcid.as_slice();

    let conf_ptr = conf_ptr as *mut quiche::Config;
    let conf = unsafe { &mut *conf_ptr };

    let scid = quiche::ConnectionId::from_ref(scid);
    let odcid = quiche::ConnectionId::from_ref(odcid);
    match quiche::accept(&scid, Some(&odcid), conf) {
        Ok(raw_conn) => {
            let conn = Connection::new(module, raw_conn, peer);
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
pub fn connection_close(conn_ptr: i64, app: bool, err: u64, reason: Binary) -> NifResult<Atom> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };

    match conn.close(app, err, reason.as_slice()) {
        Ok(_) => Ok(atoms::ok()),
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
    match conn.on_packet(&env, &pid, &mut packet.as_mut_slice()) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_on_timeout(conn_ptr: i64) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };

    match conn.on_timeout() {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_stream_send(
    conn_ptr: i64,
    stream_id: u64,
    data: Binary,
) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };
    match conn.stream_send(stream_id, data.as_slice()) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn connection_dgram_send(conn_ptr: i64, data: Binary) -> NifResult<(Atom, u64)> {
    let conn_ptr = conn_ptr as *mut Connection;
    let conn = unsafe { &mut *conn_ptr };
    match conn.dgram_send(data.as_slice()) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason) => Err(common::error_term(reason)),
    }
}
