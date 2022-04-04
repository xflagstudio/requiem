use rustler::types::binary::{Binary, OwnedBinary};
use rustler::{Atom, Env, NifResult};

use crate::common::atoms;

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
        token.as_mut_slice().copy_from_slice(t);
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

pub struct PacketBuilder {
    buf: [u8; 1500],
}

impl PacketBuilder {
    pub fn new() -> Self {
        PacketBuilder { buf: [0; 1500] }
    }

    pub fn build_negotiate_version(&mut self, scid: &[u8], dcid: &[u8]) -> OwnedBinary {
        let scid = quiche::ConnectionId::from_ref(scid);
        let dcid = quiche::ConnectionId::from_ref(dcid);
        let len = quiche::negotiate_version(&scid, &dcid, &mut self.buf).unwrap();

        let mut resp = OwnedBinary::new(len).unwrap();
        resp.as_mut_slice().copy_from_slice(&self.buf[..len]);
        resp
    }

    pub fn build_retry(
        &mut self,
        scid: &[u8],
        dcid: &[u8],
        odcid: &[u8],
        token: &[u8],
        version: u32,
    ) -> OwnedBinary {
        let scid = quiche::ConnectionId::from_ref(scid);
        let dcid = quiche::ConnectionId::from_ref(dcid);
        let odcid = quiche::ConnectionId::from_ref(odcid);
        let len = quiche::retry(&scid, &odcid, &dcid, token, version, &mut self.buf).unwrap();
        let mut resp = OwnedBinary::new(len).unwrap();
        resp.as_mut_slice().copy_from_slice(&self.buf[..len]);
        resp
    }
}

#[rustler::nif]
pub fn packet_builder_new() -> NifResult<(Atom, i64)> {
    let ptr = Box::into_raw(Box::new(PacketBuilder::new()));
    Ok((atoms::ok(), ptr as i64))
}

#[rustler::nif]
pub fn packet_builder_destroy(builder_ptr: i64) -> NifResult<Atom> {
    let builder_ptr = builder_ptr as *mut PacketBuilder;
    unsafe { drop(Box::from_raw(builder_ptr)) };
    Ok(atoms::ok())
}

#[rustler::nif]
pub fn packet_builder_build_negotiate_version<'a>(
    env: Env<'a>,
    builder_ptr: i64,
    scid: Binary,
    dcid: Binary,
) -> NifResult<(Atom, Binary<'a>)> {
    let builder_ptr = builder_ptr as *mut PacketBuilder;
    let builder = unsafe { &mut *builder_ptr };

    let resp = builder.build_negotiate_version(scid.as_slice(), dcid.as_slice());

    Ok((atoms::ok(), resp.release(env)))
}

#[rustler::nif]
pub fn packet_builder_build_retry<'a>(
    env: Env<'a>,
    builder_ptr: i64,
    scid: Binary,
    odcid: Binary,
    dcid: Binary,
    token: Binary,
    version: u32,
) -> NifResult<(Atom, Binary<'a>)> {
    let builder_ptr = builder_ptr as *mut PacketBuilder;
    let builder = unsafe { &mut *builder_ptr };

    let resp = builder.build_retry(
        scid.as_slice(),
        dcid.as_slice(),
        odcid.as_slice(),
        token.as_slice(),
        version,
    );

    Ok((atoms::ok(), resp.release(env)))
}
