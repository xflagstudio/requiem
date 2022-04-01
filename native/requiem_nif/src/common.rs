use rustler::Atom;

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
        bad_state,
        not_found,
        __drain__,
        __packet__,
        __connect__, // webtransport connect request
        __reset__, // connected stream received http3 reset event
        __finished__, // connected stream received http3 finished event
        __goaway__, // connected stream received http3 goaway event
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
