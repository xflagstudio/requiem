use rustler::env::OwnedEnv;
use rustler::types::binary::{Binary, OwnedBinary};
use rustler::types::tuple::make_tuple;
use rustler::types::{Encoder, LocalPid};
use rustler::{Atom, Env, NifResult, ResourceArc};

use parking_lot::Mutex;

use mio::net::UdpSocket;
use mio::{Events, Interest, Poll, Token};

use std::convert::TryInto;
use std::net::{IpAddr, SocketAddr};
use std::str;
use std::thread;
use std::time;

use crate::common::atoms;

pub struct Peer {
    addr: SocketAddr,
}

impl Peer {
    pub fn new(addr: SocketAddr) -> Self {
        Peer { addr: addr }
    }
}

pub struct Socket {
    sock: UdpSocket,
    poll: Poll,
    events: Events,
    buf: [u8; 65535],
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
            sock: sock,
            poll: poll,
            events: events,
            buf: buf,
        }
    }

    pub fn poll(&mut self, env: &Env, pid: &LocalPid, interval: u64) {
        let timeout = time::Duration::from_millis(interval);
        self.poll.poll(&mut self.events, Some(timeout)).unwrap();

        for event in self.events.iter() {
            match event.token() {
                Token(0) => {
                    let (len, peer) = match self.sock.recv_from(&mut self.buf) {
                        Ok(v) => v,
                        Err(_e) => {
                            /*
                            if e.kind() != std::io::ErrorKind::WouldBlock {
                                env.send(pid, make_tuple(*env, &[
                                        atoms::socket_error().to_term(*env),
                                        atoms::cant_receive().to_term(*env),
                                ]));
                                break;
                            }
                            */
                            return;
                        }
                    };
                    if len > 1350 {
                        // too big packet. ignore
                        return;
                    }

                    let mut packet = OwnedBinary::new(len).unwrap();
                    packet.as_mut_slice().copy_from_slice(&self.buf[..len]);

                    env.send(
                        pid,
                        make_tuple(
                            *env,
                            &[
                                atoms::__packet__().to_term(*env),
                                ResourceArc::new(Peer::new(peer)).encode(*env),
                                packet.release(*env).to_term(*env),
                            ],
                        ),
                    );
                }
                _ => {}
            }
        }
    }
}

pub struct LockedSocket {
    sock: Mutex<std::net::UdpSocket>,
}

impl LockedSocket {
    pub fn new(sock: std::net::UdpSocket) -> Self {
        LockedSocket {
            sock: Mutex::new(sock),
        }
    }

    pub fn send(&self, address: &SocketAddr, packet: &[u8]) -> bool {
        let raw = self.sock.lock();
        if let Err(_) = raw.send_to(packet, *address) {
            return false;
        } else {
            return true;
        }
    }
}

#[rustler::nif]
pub fn socket_open(
    address: Binary,
    pid: LocalPid,
    event_capacity: u64,
    poll_interval: u64,
) -> NifResult<(Atom, ResourceArc<LockedSocket>)> {
    let address = str::from_utf8(address.as_slice()).unwrap();

    let std_sock = std::net::UdpSocket::bind(address).unwrap();
    let std_sock2 = std_sock.try_clone().unwrap();

    let cap = event_capacity.try_into().unwrap();
    let mut receiver = Socket::new(std_sock2, cap);

    let oenv = OwnedEnv::new();
    thread::spawn(move || {
        oenv.run(|env| loop {
            receiver.poll(&env, &pid, poll_interval);
        })
    });

    let sock = ResourceArc::new(LockedSocket::new(std_sock));
    Ok((atoms::ok(), sock))
}

#[rustler::nif]
pub fn socket_send(
    sock: ResourceArc<LockedSocket>,
    peer: ResourceArc<Peer>,
    packet: Binary,
) -> NifResult<Atom> {
    let packet = packet.as_slice();
    sock.send(&peer.addr, packet);
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
    rustler::resource!(LockedSocket, env);
    true
}
