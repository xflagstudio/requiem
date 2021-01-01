use rustler::{Atom, Env, NifResult};
use rustler::types::binary::{Binary, OwnedBinary};

use once_cell::sync::Lazy;
use parking_lot::{RwLock, Mutex};

use std::collections::HashMap;

use crate::common::{self, atoms};

type GlobalBuffer = RwLock<HashMap<Vec<u8>, Mutex<[u8; 1350]>>>;
static BUFFERS: Lazy<GlobalBuffer> = Lazy::new(|| RwLock::new(HashMap::new()));

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


pub fn buffer_init(module: &[u8]) {
    let mut buffer_table = BUFFERS.write();
    if !buffer_table.contains_key(module) {
        buffer_table.insert(module.to_vec(), Mutex::new([0; 1350]));
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
pub fn packet_parse_header<'a>(env: Env<'a>, packet: Binary)
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
            Err(common::error_term(atoms::bad_format())),

    }

}

#[rustler::nif]
pub fn packet_build_negotiate_version<'a>(env: Env<'a>, module: Binary, scid: Binary, dcid: Binary)
    -> NifResult<(Atom, Binary<'a>)> {

    let module = module.as_slice();
    let buffer_table = BUFFERS.read();

    if let Some(buf) = buffer_table.get(module) {

        let mut buf = buf.lock();

        let scid = scid.as_slice();
        let dcid = dcid.as_slice();

        let len = quiche::negotiate_version(&scid, &dcid, &mut *buf).unwrap();

        let mut resp = OwnedBinary::new(len).unwrap();
        resp.as_mut_slice().copy_from_slice(&buf[..len]);

        Ok((atoms::ok(), resp.release(env)))

    } else {

        Err(common::error_term(atoms::not_found()))

    }

}

#[rustler::nif]
pub fn packet_build_retry<'a>(env: Env<'a>, module: Binary,
    scid: Binary, odcid: Binary, dcid: Binary,
    token: Binary, version: u32)
    -> NifResult<(Atom, Binary<'a>)> {

    let module = module.as_slice();
    let buffer_table = BUFFERS.read();

    if let Some(buf) = buffer_table.get(module) {

        let mut buf = buf.lock();

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

        Err(common::error_term(atoms::not_found()))

    }

}

