use std::str;

use rustler::types::binary::Binary;
use rustler::{Atom, NifResult};

use crate::common::{self, atoms};

fn set_config<F>(config: &mut quiche::Config, setter: F) -> NifResult<Atom>
    where F: FnOnce(&mut quiche::Config) -> quiche::Result<()> {
    match setter(config) {
        Ok(_) => Ok(atoms::ok()),
        Err(_) => Err(common::error_term(atoms::system_error()))
    }
}

#[rustler::nif]
pub fn config_new() -> NifResult<i64> {
    let raw = quiche::Config::new(quiche::PROTOCOL_VERSION).map_err(|_| common::error_term(atoms::system_error()))?;
    let ptr = Box::into_raw(Box::new(raw)) as i64;
    Ok(ptr)
}

#[rustler::nif]
pub fn config_destroy(cptr: i64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    unsafe { drop(Box::from_raw(cptr)) };
    Ok(atoms::ok())
}

#[rustler::nif]
pub fn config_load_cert_chain_from_pem_file(cptr: i64, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| config.load_cert_chain_from_pem_file(file))
}


#[rustler::nif]
pub fn config_load_priv_key_from_pem_file(cptr: i64, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| config.load_priv_key_from_pem_file(file))
}

#[rustler::nif]
pub fn config_load_verify_locations_from_file(cptr: i64, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.load_verify_locations_from_file(file)
    })
}

#[rustler::nif]
pub fn config_load_verify_locations_from_directory(cptr: i64, dir: Binary) -> NifResult<Atom> {
    let dir = str::from_utf8(dir.as_slice()).unwrap();
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.load_verify_locations_from_directory(dir)
    })
}

#[rustler::nif]
pub fn config_verify_peer(cptr: i64, verify: bool) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.verify_peer(verify);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_grease(cptr: i64, grease: bool) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.grease(grease);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_enable_early_data(cptr: i64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.enable_early_data();
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_application_protos(cptr: i64, protos: Binary) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_application_protos(protos.as_slice())
    })
}

#[rustler::nif]
pub fn config_set_max_idle_timeout(cptr: i64, timeout: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_max_idle_timeout(timeout);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_max_udp_payload_size(cptr: i64, size: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_max_recv_udp_payload_size(size as usize);
        config.set_max_send_udp_payload_size(size as usize);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_data(cptr: i64, v: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_initial_max_data(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_stream_data_bidi_local(cptr: i64, v: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_initial_max_stream_data_bidi_local(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_stream_data_bidi_remote(cptr: i64, v: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_initial_max_stream_data_bidi_remote(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_stream_data_uni(cptr: i64, v: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_initial_max_stream_data_uni(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_streams_bidi(cptr: i64, v: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_initial_max_streams_bidi(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_streams_uni(cptr: i64, v: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_initial_max_streams_uni(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_ack_delay_exponent(cptr: i64, v: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_ack_delay_exponent(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_max_ack_delay(cptr: i64, v: u64) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_max_ack_delay(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_disable_active_migration(cptr: i64, disabled: bool) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.set_disable_active_migration(disabled);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_cc_algorithm_name(cptr: i64, name: Binary) -> NifResult<Atom> {
    let name = str::from_utf8(name.as_slice()).unwrap();
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| config.set_cc_algorithm_name(name))
}

#[rustler::nif]
pub fn config_enable_hystart(cptr: i64, enabled: bool) -> NifResult<Atom> {
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };
    set_config(cp, |config| {
        config.enable_hystart(enabled);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_enable_dgram(
    cptr: i64,
    enabled: bool,
    recv_queue_len: u64,
    send_queue_len: u64,
) -> NifResult<Atom> {
    let recv: usize = recv_queue_len as usize;
    let send: usize = send_queue_len as usize;
    let cptr = cptr as *mut quiche::Config;
    let cp = unsafe { &mut *cptr };

    set_config(cp, |config| {
        config.enable_dgram(enabled, recv, send);
        Ok(())
    })
}
