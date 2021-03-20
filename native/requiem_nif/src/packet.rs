use rustler::types::binary::{Binary, OwnedBinary};
use rustler::{Atom, Env, NifResult, ResourceArc};

use parking_lot::Mutex;

use crate::common::{self, atoms};

pub struct PacketBuildBuffer {
    buf: Mutex<[u8; 1350]>,
}

impl PacketBuildBuffer {
    pub fn new() -> Self {
        PacketBuildBuffer {
            buf: Mutex::new([0; 1350]),
        }
    }
}

pub(crate) fn packet_type(ty: quiche::Type) -> Atom {
    match ty {
        quiche::Type::Initial => atoms::initial(),
        quiche::Type::Short => atoms::short(),
        quiche::Type::VersionNegotiation => atoms::version_negotiation(),
        quiche::Type::Retry => atoms::retry(),
        quiche::Type::Handshake => atoms::handshake(),
        quiche::Type::ZeroRTT => atoms::zero_rtt(),
    }
}

pub(crate) fn header_token_binary(hdr: &quiche::Header) -> OwnedBinary {
    if let Some(t) = hdr.token.as_ref() {
        let mut token = OwnedBinary::new(t.len()).unwrap();
        token.as_mut_slice().copy_from_slice(&t);
        token
    } else {
        OwnedBinary::new(0).unwrap()
    }
}

pub(crate) fn header_dcid_binary(hdr: &quiche::Header) -> OwnedBinary {
    let mut dcid = OwnedBinary::new(hdr.dcid.len()).unwrap();
    dcid.as_mut_slice().copy_from_slice(hdr.dcid.as_ref());
    dcid
}

pub(crate) fn header_scid_binary(hdr: &quiche::Header) -> OwnedBinary {
    let mut scid = OwnedBinary::new(hdr.scid.len()).unwrap();
    scid.as_mut_slice().copy_from_slice(hdr.scid.as_ref());
    scid
}

#[rustler::nif]
pub fn packet_build_buffer_create() -> NifResult<(Atom, ResourceArc<PacketBuildBuffer>)> {
    Ok((atoms::ok(), ResourceArc::new(PacketBuildBuffer::new())))
}

#[rustler::nif]
pub fn packet_parse_header<'a>(
    env: Env<'a>,
    packet: Binary,
) -> NifResult<(Atom, Binary<'a>, Binary<'a>, Binary<'a>, u32, Atom, bool)> {
    let mut packet = packet.to_owned().unwrap();

    match quiche::Header::from_slice(&mut packet.as_mut_slice(), quiche::MAX_CONN_ID_LEN) {
        Ok(hdr) => {
            let scid = header_scid_binary(&hdr);
            let dcid = header_dcid_binary(&hdr);
            let token = header_token_binary(&hdr);

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
        }

        Err(_) => Err(common::error_term(atoms::bad_format())),
    }
}

#[rustler::nif]
pub fn packet_build_negotiate_version<'a>(
    env: Env<'a>,
    buffer: ResourceArc<PacketBuildBuffer>,
    scid: Binary,
    dcid: Binary,
) -> NifResult<(Atom, Binary<'a>)> {
    let mut buf = buffer.buf.lock();

    let scid = scid.as_slice();
    let dcid = dcid.as_slice();

    let scid = quiche::ConnectionId::from_ref(scid);
    let dcid = quiche::ConnectionId::from_ref(dcid);

    let len = quiche::negotiate_version(&scid, &dcid, &mut *buf).unwrap();

    let mut resp = OwnedBinary::new(len).unwrap();
    resp.as_mut_slice().copy_from_slice(&buf[..len]);

    Ok((atoms::ok(), resp.release(env)))
}

#[rustler::nif]
pub fn packet_build_retry<'a>(
    env: Env<'a>,
    buffer: ResourceArc<PacketBuildBuffer>,
    scid: Binary,
    odcid: Binary,
    dcid: Binary,
    token: Binary,
    version: u32,
) -> NifResult<(Atom, Binary<'a>)> {
    let mut buf = buffer.buf.lock();

    let scid = scid.as_slice();
    let odcid = odcid.as_slice();
    let dcid = dcid.as_slice();
    let token = token.as_slice();

    let scid = quiche::ConnectionId::from_ref(scid);
    let dcid = quiche::ConnectionId::from_ref(dcid);
    let odcid = quiche::ConnectionId::from_ref(odcid);

    let len = quiche::retry(&scid, &odcid, &dcid, &token, version, &mut *buf).unwrap();

    let mut resp = OwnedBinary::new(len).unwrap();
    resp.as_mut_slice().copy_from_slice(&buf[..len]);

    Ok((atoms::ok(), resp.release(env)))
}

pub fn on_load(env: Env) -> bool {
    rustler::resource!(PacketBuildBuffer, env);
    true
}
