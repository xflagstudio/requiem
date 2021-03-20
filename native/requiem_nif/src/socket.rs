use rustler::env::OwnedEnv;
use rustler::types::binary::{Binary, OwnedBinary};
use rustler::types::tuple::make_tuple;
use rustler::types::{Encoder, LocalPid};
use rustler::{Atom, Env, ListIterator, NifResult, ResourceArc};

use once_cell::sync::Lazy;
use parking_lot::{Mutex, RwLock};

use mio::net::UdpSocket;
use mio::{Events, Interest, Poll, Token};

use std::collections::HashMap;
use std::convert::TryInto;
use std::net::{IpAddr, SocketAddr};
use std::str;
use std::sync::Arc;
use std::thread;
use std::time;

use crate::common::{self, atoms};
use crate::packet::{self};

type ModuleName = Vec<u8>;
type SocketCloser = RwLock<HashMap<ModuleName, Arc<RwLock<bool>>>>;
type SenderSocket = RwLock<HashMap<ModuleName, Mutex<std::net::UdpSocket>>>;

static CLOSERS: Lazy<SocketCloser> = Lazy::new(|| RwLock::new(HashMap::new()));
static SOCKETS: Lazy<SenderSocket> = Lazy::new(|| RwLock::new(HashMap::new()));

pub struct Peer {
    addr: SocketAddr,
}

impl Peer {
    pub fn new(addr: SocketAddr) -> Self {
        Peer { addr }
    }
}

pub struct Socket {
    sock: UdpSocket,
    poll: Poll,
    events: Events,
    buf: [u8; 65535],
    target_index: usize,
}

impl Socket {
    pub fn new(sock: std::net::UdpSocket, event_capacity: usize) -> Self {
        let buf = [0; 65535];
        let mut sock = UdpSocket::from_std(sock);

        let poll = Poll::new().unwrap();

        poll.registry()
            .register(&mut sock, Token(0), Interest::READABLE)
            .unwrap();

        let events = Events::with_capacity(event_capacity);

        Socket {
            sock,
            poll,
            events,
            buf,
            target_index: 0,
        }
    }

    pub fn poll(&mut self, env: &Env, pid: &LocalPid, target_pids: &[LocalPid], interval: u64) {
        let timeout = time::Duration::from_millis(interval);
        self.poll.poll(&mut self.events, Some(timeout)).unwrap();

        loop {
            let (len, peer) = match self.sock.recv_from(&mut self.buf) {
                Ok(v) => v,
                Err(e) => {
                    if e.kind() != std::io::ErrorKind::WouldBlock {
                        env.send(
                            pid,
                            make_tuple(
                                *env,
                                &[
                                    atoms::socket_error().to_term(*env),
                                    atoms::cant_receive().to_term(*env),
                                ],
                            ),
                        );
                    }
                    return;
                }
            };

            if len < 4 {
                // too short packet. ignore
                continue;
            }

            match quiche::Header::from_slice(&mut self.buf[..len], quiche::MAX_CONN_ID_LEN) {
                Ok(hdr) => {
                    let scid = packet::header_scid_binary(&hdr);
                    let dcid = packet::header_dcid_binary(&hdr);
                    let token = packet::header_token_binary(&hdr);

                    let version = hdr.version;

                    let typ = packet::packet_type(hdr.ty);
                    let is_version_supported = quiche::version_is_supported(hdr.version);

                    let mut body = OwnedBinary::new(len).unwrap();
                    body.as_mut_slice().copy_from_slice(&self.buf[..len]);

                    env.send(
                        &target_pids[self.target_index],
                        make_tuple(
                            *env,
                            &[
                                atoms::__packet__().to_term(*env),
                                ResourceArc::new(Peer::new(peer)).encode(*env),
                                body.release(*env).to_term(*env),
                                scid.release(*env).to_term(*env),
                                dcid.release(*env).to_term(*env),
                                token.release(*env).to_term(*env),
                                version.encode(*env),
                                typ.to_term(*env),
                                is_version_supported.encode(*env),
                            ],
                        ),
                    );

                    if self.target_index >= target_pids.len() - 1 {
                        self.target_index = 0;
                    } else {
                        self.target_index += 1;
                    }
                }
                Err(_) => {
                    // ignore
                    continue;
                }
            };
        }
    }
}
pub(crate) fn send_internal(
    module: &[u8],
    peer: &ResourceArc<Peer>,
    packet: &[u8],
) -> Result<(), Atom> {
    let socket_table = SOCKETS.read();
    if let Some(socket) = socket_table.get(module) {
        let socket = socket.lock();
        match socket.send_to(packet, &peer.addr) {
            Ok(_size) => Ok(()),
            Err(_) => Err(atoms::system_error()),
        }
    } else {
        Err(atoms::not_found())
    }
}

#[rustler::nif]
pub fn socket_address_from_string(address: Binary) -> NifResult<(Atom, ResourceArc<Peer>)> {
    let addr = match str::from_utf8(address.as_slice()) {
        Ok(v) => v,
        Err(_) => {
            return Err(common::error_term(atoms::bad_format()));
        }
    };
    let addr: SocketAddr = addr.parse().unwrap();
    Ok((atoms::ok(), ResourceArc::new(Peer::new(addr))))
}

#[rustler::nif]
pub fn socket_open(
    module: Binary,
    address: Binary,
    pid: LocalPid,
    target_pids: ListIterator,
    event_capacity: u64,
    poll_interval: u64,
) -> NifResult<Atom> {
    let module = module.as_slice();

    let targets: Vec<LocalPid> = match target_pids.map(|x| x.decode::<LocalPid>()).collect() {
        Ok(v) => v,
        Err(_) => return Err(common::error_term(atoms::system_error())),
    };

    let address = str::from_utf8(address.as_slice()).unwrap();

    let std_sock = match std::net::UdpSocket::bind(address) {
        Ok(v) => v,
        Err(_) => return Err(common::error_term(atoms::cant_bind())),
    };

    let std_sock2 = std_sock.try_clone().unwrap();

    let closer = Arc::new(RwLock::new(false));
    let closer2 = closer.clone();

    let cap = event_capacity.try_into().unwrap();
    let mut receiver = Socket::new(std_sock2, cap);

    let oenv = OwnedEnv::new();
    thread::spawn(move || {
        oenv.run(move |env| loop {
            let should_close = closer2.read();
            if *should_close {
                break;
            }
            receiver.poll(&env, &pid, &targets, poll_interval);
        })
    });

    let mut socket_table = SOCKETS.write();
    if !socket_table.contains_key(module) {
        socket_table.insert(module.to_vec(), Mutex::new(std_sock));
    }

    let mut closer_table = CLOSERS.write();
    if !closer_table.contains_key(module) {
        closer_table.insert(module.to_vec(), closer);
    }

    Ok(atoms::ok())
}

#[rustler::nif]
pub fn socket_send(module: Binary, peer: ResourceArc<Peer>, packet: Binary) -> NifResult<Atom> {
    match send_internal(module.as_slice(), &peer, packet.as_slice()) {
        Ok(()) => Ok(atoms::ok()),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn socket_close(module: Binary) -> NifResult<Atom> {
    let module = module.as_slice();

    let mut socket_table = SOCKETS.write();
    if socket_table.contains_key(module) {
        socket_table.remove(module);
    }

    let mut closer_table = CLOSERS.write();
    if closer_table.contains_key(module) {
        if let Some(closer) = closer_table.get(module) {
            let mut should_close = closer.write();
            *should_close = true;
        }

        closer_table.remove(module);
    }
    Ok(atoms::ok())
}

#[rustler::nif]
pub fn socket_address_parts(env: Env, peer: ResourceArc<Peer>) -> NifResult<(Atom, Binary, u16)> {
    let ip_bytes = match peer.addr.ip() {
        IpAddr::V4(ip) => ip.octets().to_vec(),
        IpAddr::V6(ip) => ip.octets().to_vec(),
    };

    let mut ip = OwnedBinary::new(ip_bytes.len()).unwrap();
    ip.as_mut_slice().copy_from_slice(&ip_bytes);

    Ok((atoms::ok(), ip.release(env), peer.addr.port()))
}

pub fn on_load(env: Env) -> bool {
    rustler::resource!(Peer, env);
    true
}
