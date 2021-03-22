use std::str;

use rustler::types::binary::Binary;
use rustler::{Atom, NifResult};

use crate::common::{self, atoms};

fn set_config<F>(config: &mut quiche::Config, setter: F) -> NifResult<Atom>
where
    F: FnOnce(&mut quiche::Config) -> quiche::Result<()>,
{
    match setter(config) {
        Ok(_) => Ok(atoms::ok()),
        Err(_) => Err(common::error_term(atoms::system_error())),
    }
}

#[rustler::nif]
pub fn config_new() -> NifResult<(Atom, i64)> {
    let raw = quiche::Config::new(quiche::PROTOCOL_VERSION)
        .map_err(|_| common::error_term(atoms::system_error()))?;
    let ptr = Box::into_raw(Box::new(raw)) as i64;
    Ok((atoms::ok(), ptr))
}

#[rustler::nif]
pub fn config_destroy(conf_ptr: i64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    unsafe { drop(Box::from_raw(conf_ptr)) };
    Ok(atoms::ok())
}

#[rustler::nif]
pub fn config_load_cert_chain_from_pem_file(conf_ptr: i64, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| config.load_cert_chain_from_pem_file(file))
}

#[rustler::nif]
pub fn config_load_priv_key_from_pem_file(conf_ptr: i64, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| config.load_priv_key_from_pem_file(file))
}

#[rustler::nif]
pub fn config_load_verify_locations_from_file(conf_ptr: i64, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| config.load_verify_locations_from_file(file))
}

#[rustler::nif]
pub fn config_load_verify_locations_from_directory(conf_ptr: i64, dir: Binary) -> NifResult<Atom> {
    let dir = str::from_utf8(dir.as_slice()).unwrap();
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.load_verify_locations_from_directory(dir)
    })
}

#[rustler::nif]
pub fn config_verify_peer(conf_ptr: i64, verify: bool) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.verify_peer(verify);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_grease(conf_ptr: i64, grease: bool) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.grease(grease);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_enable_early_data(conf_ptr: i64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.enable_early_data();
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_application_protos(conf_ptr: i64, protos: Binary) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_application_protos(protos.as_slice())
    })
}

#[rustler::nif]
pub fn config_set_max_idle_timeout(conf_ptr: i64, timeout: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_max_idle_timeout(timeout);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_max_udp_payload_size(conf_ptr: i64, size: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_max_recv_udp_payload_size(size as usize);
        config.set_max_send_udp_payload_size(size as usize);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_data(conf_ptr: i64, v: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_initial_max_data(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_stream_data_bidi_local(conf_ptr: i64, v: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_initial_max_stream_data_bidi_local(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_stream_data_bidi_remote(conf_ptr: i64, v: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_initial_max_stream_data_bidi_remote(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_stream_data_uni(conf_ptr: i64, v: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_initial_max_stream_data_uni(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_streams_bidi(conf_ptr: i64, v: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_initial_max_streams_bidi(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_streams_uni(conf_ptr: i64, v: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_initial_max_streams_uni(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_ack_delay_exponent(conf_ptr: i64, v: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_ack_delay_exponent(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_max_ack_delay(conf_ptr: i64, v: u64) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_max_ack_delay(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_disable_active_migration(conf_ptr: i64, disabled: bool) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.set_disable_active_migration(disabled);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_cc_algorithm_name(conf_ptr: i64, name: Binary) -> NifResult<Atom> {
    let name = str::from_utf8(name.as_slice()).unwrap();
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| config.set_cc_algorithm_name(name))
}

#[rustler::nif]
pub fn config_enable_hystart(conf_ptr: i64, enabled: bool) -> NifResult<Atom> {
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };
    set_config(cp, |config| {
        config.enable_hystart(enabled);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_enable_dgram(
    conf_ptr: i64,
    enabled: bool,
    recv_queue_len: u64,
    send_queue_len: u64,
) -> NifResult<Atom> {
    let recv: usize = recv_queue_len as usize;
    let send: usize = send_queue_len as usize;
    let conf_ptr = conf_ptr as *mut quiche::Config;
    let cp = unsafe { &mut *conf_ptr };

    set_config(cp, |config| {
        config.enable_dgram(enabled, recv, send);
        Ok(())
    })
}
