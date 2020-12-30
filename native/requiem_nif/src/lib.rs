use rustler::{Atom, Env, NifResult, ResourceArc, Term};
use rustler::types::binary::{Binary, OwnedBinary};
use rustler::types::tuple::make_tuple;
use rustler::types::{LocalPid, Encoder};

use once_cell::sync::Lazy;
use parking_lot::RwLock;

use std::str;
use std::pin::Pin;
use std::convert::{TryInto, TryFrom};
use std::sync::Mutex;
use std::collections::HashMap;

type GlobalBuffer = Mutex<[u8; 1350]>;
type GlobalBufferTable = RwLock<HashMap<Vec<u8>, GlobalBuffer>>;

type SyncConfig = Mutex<quiche::Config>;
type SyncConfigTable = RwLock<HashMap<Vec<u8>, SyncConfig>>;

static CONFIGS: Lazy<SyncConfigTable> = Lazy::new(|| RwLock::new(HashMap::new()));
static BUFFERS: Lazy<GlobalBufferTable> = Lazy::new(|| RwLock::new(HashMap::new()));

struct Connection {
    conn: Pin<Box<quiche::Connection>>,
    buf:  [u8; 1350],
}

impl Connection {

    pub fn new(conn: Pin<Box<quiche::Connection>>) -> Self {
        Connection {
            conn: conn,
            buf:  [0; 1350],
        }
    }

    pub fn on_packet(&mut self, env: &Env, pid: &LocalPid,
        packet: &mut [u8]) -> Result<u64, Atom> {

        if !self.conn.is_closed() {

            match self.conn.recv(packet) {
                Ok(_len) => {
                    self.handle_stream(env, pid);
                    self.handle_dgram(env, pid);
                    self.drain(env, pid);
                    Ok(self.next_timeout())
                },

                Err(_) =>
                    Err(atoms::system_error()),
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

            for s in self.conn.readable() {

                // XXX need more bigger buffer
                while let Ok((len, _fin)) = self.conn.stream_recv(s, &mut self.buf) {

                    let mut data = OwnedBinary::new(len).unwrap();
                    data.as_mut_slice().copy_from_slice(&self.buf[..len]);
                    // {:stream, 1, "Hello"}
                    env.send(pid, make_tuple(*env, &[
                            atoms::__stream_recv__().to_term(*env),
                            s.encode(*env),
                            data.release(*env).to_term(*env),
                    ]))
                }
            }
        }
    }

    fn stream_send(&mut self, env: &Env, pid: &LocalPid,
        stream_id: u64, data: &[u8]) -> Result<u64, Atom> {

        let size = data.len();

        if !self.conn.is_closed() {

            let mut pos = 0;
            loop {
                match self.conn.stream_send(stream_id, &data[pos..], true) {
                    Ok(len) => {
                        pos += len;
                        self.drain(env, pid);
                        if pos >= size {
                            break;
                        }
                    },
                    Err(quiche::Error::Done) => {
                        break;
                    },
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

    fn dgram_send(&mut self, env: &Env, pid: &LocalPid, data: &[u8])
        -> Result<u64, Atom> {

        if !self.conn.is_closed() {

            match self.conn.dgram_send(data) {

                Ok(()) => {
                    self.drain(env, pid);
                    Ok(self.next_timeout())
                },

                Err(_) => {
                    return Err(atoms::system_error());
                },
            }

        } else {

            Err(atoms::already_closed())

        }

    }

    fn handle_dgram(&mut self, env: &Env, pid: &LocalPid) {

        if self.conn.is_in_early_data() || self.conn.is_established() {

            while let Ok(len) = self.conn.dgram_recv(&mut self.buf) {

               let mut data = OwnedBinary::new(len).unwrap();
               data.as_mut_slice().copy_from_slice(&self.buf[..len]);

               env.send(pid, make_tuple(*env, &[
                       atoms::__dgram_recv__().to_term(*env),
                       data.release(*env).to_term(*env),
               ]));

            }
        }

    }

    pub fn on_timeout(&mut self, env: &Env, pid: &LocalPid) -> Result<u64, Atom> {
        if !self.conn.is_closed() {
            self.conn.on_timeout();
            self.drain(env, pid);
            Ok(self.next_timeout())
        } else {
            Err(atoms::already_closed())
        }
    }

    pub fn is_closed(&self) -> bool {
        self.conn.is_closed()
    }

    pub fn close(&mut self, env: &Env, pid: &LocalPid,
        app: bool, err: u64, reason: &[u8]) -> Result<(), Atom> {

        if !self.conn.is_closed() {

            match self.conn.close(app, err, reason) {

                Ok(()) => {
                    self.drain(env, pid);
                    Ok(())
                },

                Err(quiche::Error::Done) => {
                    Ok(())
                },

                Err(_) =>
                    Err(atoms::system_error()),
            }

        } else {

            Err(atoms::already_closed())
        }

    }

    fn drain(&mut self, env: &Env, pid: &LocalPid) {

        loop {

           match self.conn.send(&mut self.buf) {

               Ok(len) => {

                   let mut data = OwnedBinary::new(len).unwrap();
                   data.as_mut_slice().copy_from_slice(&self.buf[..len]);

                   env.send(pid,
                       make_tuple(*env, &[
                           atoms::__drain__().to_term(*env),
                           data.release(*env).to_term(*env),
                       ]));
               },

               Err(quiche::Error::Done) => {
                   break;
               },

               Err(_) => {
                   // XXX should return error?
                   self.conn.close(false, 0x1, b"fail").ok();
                   break;
               },

           };
        }
    }

}

struct LockedConnection {
    conn: Mutex<Connection>,
}

impl LockedConnection {

    pub fn new(raw: Pin<Box<quiche::Connection>>) -> Self {
        LockedConnection {
            conn: Mutex::new(Connection::new(raw)),
        }
    }
}

mod atoms {
    rustler::atoms! {
        ok,
        system_error,
        already_exists,
        already_closed,
        bad_format,
        not_found,
        __drain__,
        __stream_recv__,
        __dgram_recv__,
        initial, // packet type
        handshake, // packet type
        retry, // packet type
        zero_rtt, // packet type
        version_negotiation, // packet type
        short // packet type
    }
}

fn error_term(reason: Atom) -> rustler::Error {
    rustler::Error::Term(Box::new(reason))
}

fn set_config<F>(module: Binary, setter: F) -> NifResult<Atom>
    where F: FnOnce(&mut quiche::Config) -> quiche::Result<()> {

    let module = module.as_slice();
    let mut config_table = CONFIGS.write();

    if let Some(config) = config_table.get_mut(module) {

        let mut c = config.lock().unwrap();

        match setter(&mut *c) {
            Ok(()) =>
                Ok(atoms::ok()),

            Err(_) =>
                Err(error_term(atoms::system_error()))
        }

    } else {

        Err(error_term(atoms::not_found()))

    }
}

fn header_token_binary(hdr: &quiche::Header) -> NifResult<OwnedBinary> {

    if let Some(t) = hdr.token.as_ref() {

        let mut token = OwnedBinary::new(t.len()).unwrap();
        token.as_mut_slice().copy_from_slice(&t);
        Ok(token)

    } else {

        let empty = OwnedBinary::new(0).unwrap();
        Ok(empty)

    }
}

fn header_dcid_binary(hdr: &quiche::Header) -> NifResult<OwnedBinary> {
    let mut dcid = OwnedBinary::new(hdr.dcid.len()).unwrap();
    dcid.as_mut_slice().copy_from_slice(hdr.dcid.as_ref());
    Ok(dcid)
}

fn header_scid_binary(hdr: &quiche::Header) -> NifResult<OwnedBinary> {
    let mut scid = OwnedBinary::new(hdr.scid.len()).unwrap();
    scid.as_mut_slice().copy_from_slice(hdr.scid.as_ref());
    Ok(scid)
}

#[rustler::nif]
fn quic_init(module: Binary) -> NifResult<Atom> {
    let module  = module.as_slice();
    buffer_init(&module);
    config_init(&module)
}

fn config_init(module: &[u8]) -> NifResult<Atom> {

    let mut config_table = CONFIGS.write();

    if config_table.contains_key(module) {

        Ok(atoms::ok())

    } else {

        match quiche::Config::new(quiche::PROTOCOL_VERSION) {
            Ok(config) => {
                config_table.insert(module.to_vec(), Mutex::new(config));
                Ok(atoms::ok())
            },

            Err(_) =>
                Err(error_term(atoms::system_error()))
        }

    }
}

fn buffer_init(module: &[u8]) {
    let mut buffer_table = BUFFERS.write();
    if !buffer_table.contains_key(module) {
        buffer_table.insert(module.to_vec(), Mutex::new([0; 1350]));
    }
}

#[rustler::nif]
fn config_load_cert_chain_from_pem_file(module: Binary, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    set_config(module, |config| config.load_cert_chain_from_pem_file(file))
}

#[rustler::nif]
fn config_load_priv_key_from_pem_file(module: Binary, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    set_config(module, |config| config.load_priv_key_from_pem_file(file))
}

#[rustler::nif]
fn config_load_verify_locations_from_file(module: Binary, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    set_config(module, |config| config.load_verify_locations_from_file(file))
}

#[rustler::nif]
fn config_load_verify_locations_from_directory(module: Binary, dir: Binary) -> NifResult<Atom> {
    let dir = str::from_utf8(dir.as_slice()).unwrap();
    set_config(module, |config| config.load_verify_locations_from_directory(dir))
}

#[rustler::nif]
fn config_verify_peer(module: Binary, verify: bool) -> NifResult<Atom> {
    set_config(module, |config| {
        config.verify_peer(verify);
        Ok(())
    })
}

#[rustler::nif]
fn config_grease(module: Binary, grease: bool) -> NifResult<Atom> {
    set_config(module, |config| {
        config.grease(grease);
        Ok(())
    })
}

#[rustler::nif]
fn config_enable_early_data(module: Binary) -> NifResult<Atom> {
    set_config(module, |config| {
        config.enable_early_data();
        Ok(())
    })
}

#[rustler::nif]
fn config_set_application_protos(module: Binary, protos: Binary) -> NifResult<Atom> {
    set_config(module, |config| config.set_application_protos(protos.as_slice()))
}

#[rustler::nif]
fn config_set_max_idle_timeout(module: Binary, timeout: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_max_idle_timeout(timeout);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_max_udp_payload_size(module: Binary, size: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_max_udp_payload_size(size);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_initial_max_data(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_data(v);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_initial_max_stream_data_bidi_local(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_stream_data_bidi_local(v);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_initial_max_stream_data_bidi_remote(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_stream_data_bidi_remote(v);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_initial_max_stream_data_uni(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_stream_data_uni(v);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_initial_max_streams_bidi(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_streams_bidi(v);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_initial_max_streams_uni(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_streams_uni(v);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_ack_delay_exponent(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_ack_delay_exponent(v);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_max_ack_delay(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_max_ack_delay(v);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_disable_active_migration(module: Binary, disabled: bool) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_disable_active_migration(disabled);
        Ok(())
    })
}

#[rustler::nif]
fn config_set_cc_algorithm_name(module: Binary, name: Binary) -> NifResult<Atom> {
    let name = str::from_utf8(name.as_slice()).unwrap();
    set_config(module, |config| config.set_cc_algorithm_name(name))
}

#[rustler::nif]
fn config_enable_hystart(module: Binary, enabled: bool) -> NifResult<Atom> {
    set_config(module, |config| {
        config.enable_hystart(enabled);
        Ok(())
    })
}

#[rustler::nif]
fn config_enable_dgram(module: Binary, enabled: bool, recv_queue_len: u64, send_queue_len: u64)
    -> NifResult<Atom> {

    let recv: usize = recv_queue_len.try_into().unwrap();
    let send: usize = send_queue_len.try_into().unwrap();

    set_config(module, |config| {
        config.enable_dgram(enabled, recv, send);
        Ok(())
    })
}

#[rustler::nif]
fn connection_accept(module: Binary, scid: Binary, odcid: Binary)
    -> NifResult<(Atom, ResourceArc<LockedConnection>)> {

    let module = module.as_slice();
    let scid   = scid.as_slice();
    let odcid  = odcid.as_slice();

    let mut config_table = CONFIGS.write();

    if let Some(config) = config_table.get_mut(module) {

        let mut c = config.lock().unwrap();

        match quiche::accept(scid, Some(odcid), &mut c) {
            Ok(conn) =>
                Ok((atoms::ok(), ResourceArc::new(LockedConnection::new(conn)))),

            Err(_) =>
                Err(error_term(atoms::system_error())),
        }

    } else {

        Err(error_term(atoms::not_found()))

    }
}

#[rustler::nif]
fn connection_close(env: Env, pid: LocalPid,
    conn: ResourceArc<LockedConnection>, app: bool, err: u64, reason: Binary)
    -> NifResult<Atom> {

    let mut conn = conn.conn.lock().unwrap();

    match conn.close(&env, &pid, app, err, reason.as_slice()) {
        Ok(_)       => Ok(atoms::ok()),
        Err(reason) => Err(error_term(reason)),
    }

}

#[rustler::nif]
fn connection_is_closed(conn: ResourceArc<LockedConnection>) -> bool {
    let conn = conn.conn.lock().unwrap();
    conn.is_closed()
}

#[rustler::nif]
fn connection_on_packet(env: Env, pid: LocalPid,
    conn: ResourceArc<LockedConnection>, packet: Binary)
    -> NifResult<(Atom, u64)> {

    let mut conn = conn.conn.lock().unwrap();
    let mut packet = packet.to_owned().unwrap();

    match conn.on_packet(&env, &pid, &mut packet.as_mut_slice()) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason)      => Err(error_term(reason)),
    }

}

#[rustler::nif]
fn connection_on_timeout(env: Env, pid: LocalPid,
    conn: ResourceArc<LockedConnection>)
    -> NifResult<(Atom, u64)> {

    let mut conn = conn.conn.lock().unwrap();

    match conn.on_timeout(&env, &pid) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason)      => Err(error_term(reason)),
    }

}

#[rustler::nif]
fn connection_stream_send(env: Env, pid: LocalPid,
    conn: ResourceArc<LockedConnection>, stream_id: u64, data: Binary)
    -> NifResult<(Atom, u64)> {

        let mut conn = conn.conn.lock().unwrap();
    match conn.stream_send(&env, &pid, stream_id, data.as_slice()) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason)      => Err(error_term(reason)),
    }
}

#[rustler::nif]
fn connection_dgram_send(env: Env, pid: LocalPid,
    conn: ResourceArc<LockedConnection>, data: Binary)
    -> NifResult<(Atom, u64)> {

        let mut conn = conn.conn.lock().unwrap();
    match conn.dgram_send(&env, &pid, data.as_slice()) {
        Ok(next_timeout) => Ok((atoms::ok(), next_timeout)),
        Err(reason)      => Err(error_term(reason)),
    }
}

#[rustler::nif]
fn packet_parse_header<'a>(env: Env<'a>, packet: Binary)
    -> NifResult<(Atom, Binary<'a>, Binary<'a>, Binary<'a>, u32, Atom, bool)> {

    let mut packet = packet.to_owned().unwrap();

    match quiche::Header::from_slice(
        &mut packet.as_mut_slice(),
        quiche::MAX_CONN_ID_LEN,
    ) {

        Ok(hdr) => {

            let scid  = header_scid_binary(&hdr)?;
            let dcid  = header_dcid_binary(&hdr)?;
            let token = header_token_binary(&hdr)?;

            let version = hdr.version;

            let typ = packet_type(hdr.ty);
            let is_version_supported = quiche::version_is_supported(hdr.version);

            Ok((
                atoms::ok(),
                scid.release(env),
                dcid.release(env),
                token.release(env),
                version,
                typ,
                is_version_supported,
            ))
        },

        Err(_) =>
            Err(error_term(atoms::bad_format())),

    }

}

fn packet_type(ty: quiche::Type) -> Atom {
    match ty {
        quiche::Type::Initial            => atoms::initial(),
        quiche::Type::Short              => atoms::short(),
        quiche::Type::VersionNegotiation => atoms::version_negotiation(),
        quiche::Type::Retry              => atoms::retry(),
        quiche::Type::Handshake          => atoms::handshake(),
        quiche::Type::ZeroRTT            => atoms::zero_rtt()
    }
}

#[rustler::nif]
fn packet_build_negotiate_version<'a>(env: Env<'a>, module: Binary, scid: Binary, dcid: Binary)
    -> NifResult<(Atom, Binary<'a>)> {

    let module = module.as_slice();
    let mut buffer_table = BUFFERS.write();

    if let Some(buffer) = buffer_table.get_mut(module) {

        let mut buf = buffer.lock().unwrap();

        let scid = scid.as_slice();
        let dcid = dcid.as_slice();

        let len = quiche::negotiate_version(&scid, &dcid, &mut *buf).unwrap();

        let mut resp = OwnedBinary::new(len).unwrap();
        resp.as_mut_slice().copy_from_slice(&buf[..len]);

        Ok((atoms::ok(), resp.release(env)))

    } else {

        Err(error_term(atoms::not_found()))

    }

}

#[rustler::nif]
fn packet_build_retry<'a>(env: Env<'a>, module: Binary,
    scid: Binary, odcid: Binary, dcid: Binary,
    token: Binary, version: u32)
    -> NifResult<(Atom, Binary<'a>)> {

    let module = module.as_slice();
    let mut buffer_table = BUFFERS.write();

    if let Some(buffer) = buffer_table.get_mut(module) {

        let mut buf = buffer.lock().unwrap();

        let scid  = scid.as_slice();
        let odcid = odcid.as_slice();
        let dcid  = dcid.as_slice();
        let token = token.as_slice();

        let len = quiche::retry(
            &scid,
            &odcid,
            &dcid,
            &token,
            version,
            &mut *buf,
        ).unwrap();

        let mut resp = OwnedBinary::new(len).unwrap();
        resp.as_mut_slice().copy_from_slice(&buf[..len]);

        Ok((atoms::ok(), resp.release(env)))

    } else {

        Err(error_term(atoms::not_found()))

    }

}

rustler::init!(
    "Elixir.Requiem.QUIC.NIF",
    [
        quic_init,
        config_load_cert_chain_from_pem_file,
        config_load_priv_key_from_pem_file,
        config_load_verify_locations_from_file,
        config_load_verify_locations_from_directory,
        config_verify_peer,
        config_grease,
        config_enable_early_data,
        config_set_application_protos,
        config_set_max_idle_timeout,
        config_set_max_udp_payload_size,
        config_set_initial_max_data,
        config_set_initial_max_stream_data_bidi_local,
        config_set_initial_max_stream_data_bidi_remote,
        config_set_initial_max_stream_data_uni,
        config_set_initial_max_streams_bidi,
        config_set_initial_max_streams_uni,
        config_set_ack_delay_exponent,
        config_set_max_ack_delay,
        config_set_disable_active_migration,
        config_set_cc_algorithm_name,
        config_enable_hystart,
        config_enable_dgram,

        packet_parse_header,
        packet_build_negotiate_version,
        packet_build_retry,

        connection_accept,
        connection_close,
        connection_is_closed,
        connection_on_packet,
        connection_on_timeout,
        connection_stream_send,
        connection_dgram_send,
    ],
    load = load
);

fn load(env: Env, _: Term) -> bool {
    rustler::resource!(LockedConnection, env);
    true
}

