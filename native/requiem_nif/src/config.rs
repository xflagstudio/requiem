use rustler::{Atom, NifResult};
use rustler::types::binary::Binary;

use once_cell::sync::Lazy;
use parking_lot::{RwLock, Mutex};

use std::str;
use std::convert::TryInto;
use std::collections::HashMap;

use crate::common::{self, atoms};

type ModuleName = Vec<u8>;
type SyncConfig = RwLock<HashMap<ModuleName, Mutex<quiche::Config>>>;

pub(crate) static CONFIGS: Lazy<SyncConfig> = Lazy::new(|| RwLock::new(HashMap::new()));

pub fn config_init(module: &[u8]) -> NifResult<Atom> {

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
                Err(common::error_term(atoms::system_error()))
        }

    }
}

fn set_config<F>(module: Binary, setter: F) -> NifResult<Atom>
    where F: FnOnce(&mut quiche::Config) -> quiche::Result<()> {

    let module = module.as_slice();
    let config_table = CONFIGS.read();

    if let Some(config) = config_table.get(module) {

        let mut config = config.lock();

        match setter(&mut *config) {
            Ok(()) =>
                Ok(atoms::ok()),

            Err(_) =>
                Err(common::error_term(atoms::system_error()))
        }

    } else {

        Err(common::error_term(atoms::not_found()))

    }
}

#[rustler::nif]
pub fn config_load_cert_chain_from_pem_file(module: Binary, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    set_config(module, |config| config.load_cert_chain_from_pem_file(file))
}

#[rustler::nif]
pub fn config_load_priv_key_from_pem_file(module: Binary, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    set_config(module, |config| config.load_priv_key_from_pem_file(file))
}

#[rustler::nif]
pub fn config_load_verify_locations_from_file(module: Binary, file: Binary) -> NifResult<Atom> {
    let file = str::from_utf8(file.as_slice()).unwrap();
    set_config(module, |config| config.load_verify_locations_from_file(file))
}

#[rustler::nif]
pub fn config_load_verify_locations_from_directory(module: Binary, dir: Binary) -> NifResult<Atom> {
    let dir = str::from_utf8(dir.as_slice()).unwrap();
    set_config(module, |config| config.load_verify_locations_from_directory(dir))
}

#[rustler::nif]
pub fn config_verify_peer(module: Binary, verify: bool) -> NifResult<Atom> {
    set_config(module, |config| {
        config.verify_peer(verify);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_grease(module: Binary, grease: bool) -> NifResult<Atom> {
    set_config(module, |config| {
        config.grease(grease);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_enable_early_data(module: Binary) -> NifResult<Atom> {
    set_config(module, |config| {
        config.enable_early_data();
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_application_protos(module: Binary, protos: Binary) -> NifResult<Atom> {
    set_config(module, |config| config.set_application_protos(protos.as_slice()))
}

#[rustler::nif]
pub fn config_set_max_idle_timeout(module: Binary, timeout: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_max_idle_timeout(timeout);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_max_udp_payload_size(module: Binary, size: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_max_udp_payload_size(size);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_data(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_data(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_stream_data_bidi_local(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_stream_data_bidi_local(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_stream_data_bidi_remote(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_stream_data_bidi_remote(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_stream_data_uni(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_stream_data_uni(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_streams_bidi(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_streams_bidi(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_initial_max_streams_uni(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_initial_max_streams_uni(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_ack_delay_exponent(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_ack_delay_exponent(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_max_ack_delay(module: Binary, v: u64) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_max_ack_delay(v);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_disable_active_migration(module: Binary, disabled: bool) -> NifResult<Atom> {
    set_config(module, |config| {
        config.set_disable_active_migration(disabled);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_set_cc_algorithm_name(module: Binary, name: Binary) -> NifResult<Atom> {
    let name = str::from_utf8(name.as_slice()).unwrap();
    set_config(module, |config| config.set_cc_algorithm_name(name))
}

#[rustler::nif]
pub fn config_enable_hystart(module: Binary, enabled: bool) -> NifResult<Atom> {
    set_config(module, |config| {
        config.enable_hystart(enabled);
        Ok(())
    })
}

#[rustler::nif]
pub fn config_enable_dgram(module: Binary, enabled: bool, recv_queue_len: u64, send_queue_len: u64)
    -> NifResult<Atom> {

    let recv: usize = recv_queue_len.try_into().unwrap();
    let send: usize = send_queue_len.try_into().unwrap();

    set_config(module, |config| {
        config.enable_dgram(enabled, recv, send);
        Ok(())
    })
}

