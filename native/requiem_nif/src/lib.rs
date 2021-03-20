use rustler::types::binary::Binary;
use rustler::{Atom, Env, NifResult, Term};

mod common;
mod config;
mod connection;
mod packet;
mod socket;

#[rustler::nif]
fn quic_init(module: Binary, stream_buffer_num: u64, stream_buffer_size: usize) -> NifResult<Atom> {
    let module = module.as_slice();
    connection::buffer_init(&module, stream_buffer_num, stream_buffer_size);
    Ok(common::atoms::ok())
}

rustler::init!(
    "Elixir.Requiem.QUIC.NIF",
    [
        quic_init,
        config::config_new,
        config::config_destroy,
        config::config_load_cert_chain_from_pem_file,
        config::config_load_priv_key_from_pem_file,
        config::config_load_verify_locations_from_file,
        config::config_load_verify_locations_from_directory,
        config::config_verify_peer,
        config::config_grease,
        config::config_enable_early_data,
        config::config_set_application_protos,
        config::config_set_max_idle_timeout,
        config::config_set_max_udp_payload_size,
        config::config_set_initial_max_data,
        config::config_set_initial_max_stream_data_bidi_local,
        config::config_set_initial_max_stream_data_bidi_remote,
        config::config_set_initial_max_stream_data_uni,
        config::config_set_initial_max_streams_bidi,
        config::config_set_initial_max_streams_uni,
        config::config_set_ack_delay_exponent,
        config::config_set_max_ack_delay,
        config::config_set_disable_active_migration,
        config::config_set_cc_algorithm_name,
        config::config_enable_hystart,
        config::config_enable_dgram,
        packet::packet_build_buffer_create,
        packet::packet_parse_header,
        packet::packet_build_negotiate_version,
        packet::packet_build_retry,
        connection::connection_accept,
        connection::connection_close,
        connection::connection_is_closed,
        connection::connection_on_packet,
        connection::connection_on_timeout,
        connection::connection_stream_send,
        connection::connection_dgram_send,
        socket::socket_open,
        socket::socket_send,
        socket::socket_close,
        socket::socket_address_parts,
        socket::socket_address_from_string,
    ],
    load = load
);

fn load(env: Env, _: Term) -> bool {
    connection::on_load(env);
    packet::on_load(env);
    socket::on_load(env);
    true
}
