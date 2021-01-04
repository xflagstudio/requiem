use ring::rand::{SecureRandom, SystemRandom};
use rustler::Atom;
use std::convert::TryInto;

pub(crate) mod atoms {
    rustler::atoms! {
        ok,
        system_error,
        socket_error,
        cant_receive,
        cant_bind,
        already_exists,
        already_closed,
        bad_format,
        not_found,
        __drain__,
        __packet__,
        __stream_recv__,
        __dgram_recv__,
        initial,             // packet type
        handshake,           // packet type
        retry,               // packet type
        zero_rtt,            // packet type
        version_negotiation, // packet type
        short                // packet type
    }
}

pub(crate) fn error_term(reason: Atom) -> rustler::Error {
    rustler::Error::Term(Box::new(reason))
}

pub(crate) fn random() -> u64 {
    let mut data = [0; 8];
    let rand = SystemRandom::new();
    rand.fill(&mut data).unwrap();
    u64::from_be_bytes(data)
}

pub(crate) fn random_slot_index(size: usize) -> usize {
    let r: usize = random().try_into().unwrap();
    r % size
}
