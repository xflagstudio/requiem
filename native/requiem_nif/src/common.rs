use rustler::Atom;

pub(crate) mod atoms {
    rustler::atoms! {
        ok,
        system_error,
        socket_error,
        cant_receive,
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

