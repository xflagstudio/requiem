use std::net::{IpAddr, SocketAddr, UdpSocket};
//use std::os::unix::io::AsRawFd;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::str;
use std::sync::{Arc, Barrier};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use rustler::env::OwnedEnv;
use rustler::types::binary::{Binary, OwnedBinary};
use rustler::types::tuple::make_tuple;
use rustler::types::{Encoder, LocalPid};
use rustler::{Atom, Env, ListIterator, NifResult, ResourceArc};

use crossbeam_channel::{bounded, select, unbounded, Receiver, Sender};
//use nix::sched::CpuSet;
//use nix::sched::{sched_setaffinity, CpuSet};
//use nix::unistd::gettid;
use socket2::{Domain, Protocol, Socket, Type};

use crate::common::{self, atoms};
use crate::packet;

pub struct Peer {
    pub addr: SocketAddr,
}

impl Peer {
    pub fn new(addr: SocketAddr) -> Self {
        Peer { addr }
    }
}

#[derive(Eq, PartialEq)]
enum ClusterState {
    Idle,
    Started,
    Closed,
}

pub struct SocketCluster {
    num_node: usize,
    r_handles: Vec<Option<JoinHandle<()>>>,
    r_closers: Vec<Sender<()>>,
    s_handles: Vec<Option<JoinHandle<()>>>,
    s_closers: Vec<Sender<()>>,
    s_senders: Vec<Sender<(SocketAddr, Vec<u8>)>>,
    s_receivers: Vec<Receiver<(SocketAddr, Vec<u8>)>>,
    barrier: Arc<Barrier>,
    state: ClusterState,
    read_timeout: u64,
    write_timeout: u64,
}

impl SocketCluster {
    fn build_socket(addr: &str, read_timeout: u64, write_timeout: u64) -> Result<UdpSocket, Atom> {
        let addr = addr
            .parse::<SocketAddr>()
            .map_err(|_| atoms::bad_format())?;

        let domain = if addr.is_ipv4() {
            Domain::ipv4()
        } else {
            Domain::ipv6()
        };

        let sock = Socket::new(domain, Type::dgram(), Some(Protocol::udp()))
            .map_err(|_| atoms::socket_error())?;

        sock.set_reuse_address(true)
            .map_err(|_| atoms::socket_error())?;

        sock.set_reuse_port(true)
            .map_err(|_| atoms::socket_error())?;

        sock.set_read_timeout(Some(Duration::from_millis(read_timeout)))
            .map_err(|_| atoms::socket_error())?;

        sock.set_write_timeout(Some(Duration::from_millis(write_timeout)))
            .map_err(|_| atoms::socket_error())?;

        sock.bind(&addr.into()).map_err(|_| atoms::socket_error())?;

        let std_sock = sock.into_udp_socket();

        Ok(std_sock)
    }

    pub fn new(num_node: usize, read_timeout: u64, write_timeout: u64) -> Self {
        let mut s_senders = Vec::with_capacity(num_node);
        let mut s_receivers = Vec::with_capacity(num_node);
        for _ in 0..num_node {
            let (tx, rx) = unbounded::<(SocketAddr, Vec<u8>)>();
            s_senders.push(tx);
            s_receivers.push(rx);
        }
        Self {
            num_node,
            r_handles: Vec::with_capacity(num_node),
            r_closers: Vec::with_capacity(num_node),
            s_handles: Vec::with_capacity(num_node),
            s_closers: Vec::with_capacity(num_node),
            s_senders,
            s_receivers,
            barrier: Arc::new(Barrier::new(num_node * 2)),
            state: ClusterState::Idle,
            read_timeout,
            write_timeout,
        }
    }

    pub fn get_num_node(&self) -> usize {
        self.num_node
    }

    pub fn is_started(&self) -> bool {
        self.state == ClusterState::Started
    }

    pub fn start(
        &mut self,
        addr: &str,
        caller_pid: &LocalPid,
        target_pids: &[LocalPid],
    ) -> Result<(), Atom> {
        if self.state != ClusterState::Idle {
            return Err(atoms::bad_state());
        }

        let num_node = self.num_node;

        let mut sockets: Vec<Option<UdpSocket>> = Vec::with_capacity(num_node);

        for _n in 0..num_node {
            let sock = Self::build_socket(addr, self.read_timeout, self.write_timeout)?;
            sockets.push(Some(sock));
        }

        let step = target_pids.len() / self.num_node;

        for (n, sock) in sockets.iter_mut().enumerate() {
            let r_sock = sock.take().unwrap();
            let s_sock = r_sock.try_clone().unwrap();
            self.start_receiver_thread(n, r_sock, caller_pid, target_pids, step);
            self.start_sender_thread(n, s_sock);
        }

        Ok(())
    }

    pub fn sender(&self, idx: usize) -> Sender<(SocketAddr, Vec<u8>)> {
        self.s_senders[idx].clone()
    }

    pub fn stop(&mut self) {
        if !self.is_started() {
            return;
        }
        self.state = ClusterState::Closed;
        for r_closer in self.r_closers.iter() {
            let _ = r_closer.send(());
        }
        for s_closer in self.s_closers.iter() {
            let _ = s_closer.send(());
        }
        for r_handle in self.r_handles.iter_mut() {
            if let Some(handle) = r_handle.take() {
                let _ = handle.join();
            }
        }
        for s_handle in self.s_handles.iter_mut() {
            if let Some(handle) = s_handle.take() {
                let _ = handle.join();
            }
        }
    }

    fn start_receiver_thread(
        &mut self,
        nth: usize,
        sock: UdpSocket,
        caller_pid: &LocalPid,
        target_pids: &[LocalPid],
        step: usize,
    ) {
        let (closer_tx, closer_rx) = bounded::<()>(1);
        self.r_closers.push(closer_tx);

        let barrier = self.barrier.clone();

        let mut oenv = OwnedEnv::new();

        let pid = caller_pid.clone();

        let target_pid_start = nth * step;
        let target_pid_end = (nth + 1) * step;

        let target_pids = target_pids[target_pid_start..target_pid_end].to_vec();

        let handle = thread::spawn(move || {
            //oenv.run(move |env| {

            let mut buf = [0u8; 65535];

            barrier.wait();

            loop {
                select! {
                    recv(closer_rx) -> _ => {
                        break;
                    },
                    default => {
                        match sock.recv_from(&mut buf) {
                            Ok((len, peer)) => {

                                if len < 4 {
                                    continue;
                                }

                                if len > 1500 {
                                    continue;
                                }

                                match quiche::Header::from_slice(&mut buf[..len], quiche::MAX_CONN_ID_LEN) {

                                    Ok(hdr) => {
                                        let scid = packet::header_scid_binary(&hdr);
                                        let dcid = packet::header_dcid_binary(&hdr);
                                        let token = packet::header_token_binary(&hdr);

                                        let version = hdr.version;

                                        let typ = packet::packet_type(hdr.ty);
                                        let is_version_supported = quiche::version_is_supported(hdr.version);

                                        let mut body = OwnedBinary::new(len).unwrap();
                                        body.as_mut_slice().copy_from_slice(&buf[..len]);

                                        // TODO
                                        // 下記のtarget_indexは、peerのアドレスの値のhashから算出するようにする
                                        let mut hasher = DefaultHasher::new();
                                        peer.hash(&mut hasher);
                                        let idx = hasher.finish() % (target_pids.len() as u64);

                                        oenv.send_and_clear(
                                            &target_pids[idx as usize],
                                            |env| {
                                                make_tuple(
                                                    env,
                                                    &[
                                                        atoms::__packet__().to_term(env),
                                                        ResourceArc::new(Peer::new(peer)).encode(env),
                                                        body.release(env).to_term(env),
                                                        scid.release(env).to_term(env),
                                                        dcid.release(env).to_term(env),
                                                        token.release(env).to_term(env),
                                                        version.encode(env),
                                                        typ.to_term(env),
                                                        is_version_supported.encode(env),
                                                    ],
                                                )
                                            }
                                        );
                                    },
                                    Err(_) => {
                                        // this is not a QUIC packet, ignore.
                                        continue;
                                    }
                                }
                            },
                            Err(e) => {
                                match e.kind() {
                                    std::io::ErrorKind::WouldBlock => {
                                        continue;
                                    },
                                    _ => {
                                        oenv.send_and_clear(&pid, |env| {
                                            make_tuple(env, &[
                                                atoms::socket_error().to_term(env),
                                                atoms::cant_receive().to_term(env),
                                            ])
                                        });
                                        continue;
                                    }
                                }
                            }
                        }
                    },
                }
            }

            //});
        });

        self.r_handles.push(Some(handle));
    }

    fn start_sender_thread(&mut self, nth: usize, sock: UdpSocket) {
        let (closer_tx, closer_rx) = bounded::<()>(1);
        self.s_closers.push(closer_tx);

        let sender_rx = self.s_receivers[nth].clone();

        let barrier = self.barrier.clone();

        let handle = thread::spawn(move || {
            barrier.wait();

            loop {
                select! {
                    recv(closer_rx) -> _ => {
                        break;
                    },
                    recv(sender_rx) -> msg => {
                        if let Ok((peer, packet)) = msg {
                            'send: loop {
                                match sock.send_to(&packet, peer) {
                                    Ok(_) => {
                                        break 'send;
                                    },
                                    Err(e) => {
                                        match e.kind() {
                                            std::io::ErrorKind::WouldBlock => {
                                                continue 'send;
                                            },
                                            _ => {
                                                //error!("sender IO error: {:?}", e);
                                                break 'send;
                                            }

                                        }
                                    },
                                }
                            }
                        }
                    }
                }
            }
        });

        self.s_handles.push(Some(handle));
    }
}

impl Drop for SocketCluster {
    fn drop(&mut self) {
        self.stop();
    }
}

#[rustler::nif]
pub fn cpu_num() -> i32 {
    num_cpus::get() as i32
}

#[rustler::nif]
pub fn socket_sender_get(socket_ptr: i64, idx: i32) -> NifResult<(Atom, i64)> {
    let socket_ptr = socket_ptr as *mut SocketCluster;
    let socket = unsafe { &mut *socket_ptr };
    let sender = socket.sender(idx as usize);
    let sender_ptr = Box::into_raw(Box::new(sender));
    Ok((atoms::ok(), sender_ptr as i64))
}

#[rustler::nif]
pub fn socket_sender_send(
    sender_ptr: i64,
    peer: ResourceArc<Peer>,
    data: Binary,
) -> NifResult<Atom> {
    let sender_ptr = sender_ptr as *mut Sender<(SocketAddr, Vec<u8>)>;
    let sender = unsafe { &mut *sender_ptr };
    let _ = sender.send((peer.addr, data.as_slice().to_vec()));
    Ok(atoms::ok())
}

#[rustler::nif]
pub fn socket_sender_destroy(sender_ptr: i64) -> NifResult<Atom> {
    let sender_ptr = sender_ptr as *mut Sender<(SocketAddr, Vec<u8>)>;
    unsafe { drop(Box::from_raw(sender_ptr)) };
    Ok(atoms::ok())
}

#[rustler::nif]
pub fn socket_new(num_node: i32, read_timeout: u64, write_timeout: u64) -> NifResult<(Atom, i64)> {
    let num_node = num_node as usize;
    let socket = SocketCluster::new(num_node, read_timeout, write_timeout);

    let socket_ptr = Box::into_raw(Box::new(socket));
    Ok((atoms::ok(), socket_ptr as i64))
}

#[rustler::nif]
pub fn socket_start(
    socket_ptr: i64,
    address: Binary,
    pid: LocalPid,
    target_pids: ListIterator,
) -> NifResult<Atom> {
    let socket_ptr = socket_ptr as *mut SocketCluster;
    let socket = unsafe { &mut *socket_ptr };

    let targets: Vec<LocalPid> = match target_pids.map(|x| x.decode::<LocalPid>()).collect() {
        Ok(v) => v,
        Err(_) => return Err(common::error_term(atoms::system_error())),
    };

    let num_node = socket.get_num_node();
    if targets.len() < num_node || targets.len() % num_node != 0 {
        // TODO better error type
        return Err(common::error_term(atoms::system_error()));
    }

    let address = str::from_utf8(address.as_slice()).unwrap();

    match socket.start(address, &pid, &targets) {
        Ok(()) => Ok(atoms::ok()),
        Err(reason) => Err(common::error_term(reason)),
    }
}

#[rustler::nif]
pub fn socket_destroy(socket_ptr: i64) -> NifResult<Atom> {
    let socket_ptr = socket_ptr as *mut SocketCluster;
    unsafe { drop(Box::from_raw(socket_ptr)) };
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

pub fn on_load(env: Env) -> bool {
    rustler::resource!(Peer, env);
    true
}
