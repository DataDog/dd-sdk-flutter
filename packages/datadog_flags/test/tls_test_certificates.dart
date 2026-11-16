// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Test-only certificates and keys for TLS pinning tests. Do not use them
// outside tests.
//
// Generated with OpenSSL:
//
//   openssl ecparam -name prime256v1 -genkey -noout -out ca.key
//   openssl req -x509 -new -key ca.key -sha256 -days 36500 \
//     -subj "/CN=datadog_flags test CA" \
//     -addext "basicConstraints=critical,CA:TRUE" \
//     -addext "keyUsage=critical,keyCertSign,cRLSign" -out ca.pem
//   openssl ecparam -name prime256v1 -genkey -noout | \
//     openssl pkcs8 -topk8 -nocrypt -out a.key           # EC P-256
//   openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out b.key
//   # For each leaf, with leaf.ext containing basicConstraints=CA:FALSE,
//   # extendedKeyUsage=serverAuth, and subjectAltName=DNS:localhost:
//   openssl req -new -key a.key -subj "/CN=localhost" -out a.csr
//   openssl x509 -req -in a.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
//     -days 825 -sha256 -extfile leaf.ext -out a.pem
//
// Apple platforms reject TLS server certificates that are valid for more than
// 825 days, so the leaf certificates expire on 2029-02-18. To renew them,
// sign new certificates for the same keys. The SPKI pins do not change.
//
// Each SPKI pin is the output of:
//
//   openssl x509 -in a.pem -pubkey -noout | \
//     openssl pkey -pubin -outform der | \
//     openssl dgst -sha256 -binary | base64

/// Self-signed EC P-256 CA that issued [leafAEcCertificatePem] and
/// [leafBRsaCertificatePem].
const caCertificatePem = '''
-----BEGIN CERTIFICATE-----
MIIBhjCCASygAwIBAgIUbfrl4EILAGtrnuLI3JhbxosclDYwCgYIKoZIzj0EAwIw
IDEeMBwGA1UEAwwVZGF0YWRvZ19mbGFncyB0ZXN0IENBMCAXDTI2MTExNjE5NTkw
MloYDzIxMjYxMDIzMTk1OTAyWjAgMR4wHAYDVQQDDBVkYXRhZG9nX2ZsYWdzIHRl
c3QgQ0EwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARFENJPxjHuSLah+J3ddt6v
ySg1hrTNPxg5jSTaUqmkaq6ttixTVVNC55d0Honk7Xkoi3VrHCSGmcvjvpW6lGDm
o0IwQDAdBgNVHQ4EFgQUOptfLPHorzkQgCg5nmrgPFzB0Y4wDwYDVR0TAQH/BAUw
AwEB/zAOBgNVHQ8BAf8EBAMCAQYwCgYIKoZIzj0EAwIDSAAwRQIhANZND8y0gulM
cQm3iYu2hi8S9TTpfdLRd0faLOjyMw4CAiAT2r3ghc24eqNt8n10GhVVW+baf9oV
DstO/dhQKAP7SA==
-----END CERTIFICATE-----
''';

/// SPKI pin of [caCertificatePem].
const caSpkiPin = 'r3yCVfW66SDp+Oz8JiSTpMYbgfhOnlfdZZGfEsScAZg=';

/// Leaf certificate A for `localhost` with an EC P-256 key.
const leafAEcCertificatePem = '''
-----BEGIN CERTIFICATE-----
MIIBgTCCASegAwIBAgIUV1QEu0inauFB9fiWnn5ikr1FQTMwCgYIKoZIzj0EAwIw
IDEeMBwGA1UEAwwVZGF0YWRvZ19mbGFncyB0ZXN0IENBMB4XDTI2MTExNjIwMDUw
OFoXDTI5MDIxODIwMDUwOFowFDESMBAGA1UEAwwJbG9jYWxob3N0MFkwEwYHKoZI
zj0CAQYIKoZIzj0DAQcDQgAE2HabutAiyV5uJX7Y4Qx3TqGv98ZH+wR0AANECZkq
pah6N7CrfpRTTS1FCqni9ffLKFCbytkSYZBG3oyuZNMrraNLMEkwDAYDVR0TAQH/
BAIwADAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwFAYDVR0R
BA0wC4IJbG9jYWxob3N0MAoGCCqGSM49BAMCA0gAMEUCIHJ0bUUlKWYQOoY0EB9i
cy/JqRq5MWYlLegG8fsLFxdhAiEAqwQqYFxelbKn9fW4y8lMA+ScYZ0g07To/2M0
5tOnn/w=
-----END CERTIFICATE-----
''';

/// PKCS #8 private key of [leafAEcCertificatePem].
const leafAEcPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgEw4PKT0HzZrTqWmw
TedED5GCwywEICz1keJspkrLRyChRANCAATYdpu60CLJXm4lftjhDHdOoa/3xkf7
BHQAA0QJmSqlqHo3sKt+lFNNLUUKqeL198soUJvK2RJhkEbejK5k0yut
-----END PRIVATE KEY-----
''';

/// SPKI pin of [leafAEcCertificatePem].
const leafAEcSpkiPin = '/a7eJHpXqWw49/Mj8rt0wUeqAsR29bDHZ/1NFb6JpAw=';

/// Leaf certificate B for `localhost` with an RSA 2048 key.
const leafBRsaCertificatePem = '''
-----BEGIN CERTIFICATE-----
MIICSzCCAfKgAwIBAgIUV1QEu0inauFB9fiWnn5ikr1FQTQwCgYIKoZIzj0EAwIw
IDEeMBwGA1UEAwwVZGF0YWRvZ19mbGFncyB0ZXN0IENBMB4XDTI2MTExNjIwMDUw
OFoXDTI5MDIxODIwMDUwOFowFDESMBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkq
hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuZWJJNPs+vGJcRLnoa9vxt7PL5Ia7jqc
XPtDUnHyE1DFRQy7Sw+9q+u79nwKKWcvJMoZDYjV06gMUFTV44gwXxQb6AhZvTwY
u2VzfwYIuFp+LJ7uBxZmyrNxX+4A7V7c9jB63GQtv5/VsWsp04jC6Rb/Ab3+visS
5oZ0WXM2MA7W+77TDf7UG80THZ9gSGhxTjPCsmBeq6L+HsOI+KEJzSsIpQ0rGpqN
bNJjKz6NL5tJXNlvWgRuZhmPTQCM7RIjSc6tHrO9Wjp+QT77RauNKKQ7HPcRyINp
iGecNEtvJ8eGlFrBapCn/H7OBzxnt7xzEL5QyCO6vvSD1KiTlDyRrwIDAQABo0sw
STAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIFoDATBgNVHSUEDDAKBggrBgEF
BQcDATAUBgNVHREEDTALgglsb2NhbGhvc3QwCgYIKoZIzj0EAwIDRwAwRAIgXzh7
TNpnx4CZt3cdM6O6hC0I59ws8XtPTE3HTweg6cgCIG5SpLGCeX5ifQrub2b6dOyA
zh1lQ9SuhTPYiT+3I/YW
-----END CERTIFICATE-----
''';

/// PKCS #8 private key of [leafBRsaCertificatePem].
const leafBRsaPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC5lYkk0+z68Ylx
Euehr2/G3s8vkhruOpxc+0NScfITUMVFDLtLD72r67v2fAopZy8kyhkNiNXTqAxQ
VNXjiDBfFBvoCFm9PBi7ZXN/Bgi4Wn4snu4HFmbKs3Ff7gDtXtz2MHrcZC2/n9Wx
aynTiMLpFv8Bvf6+KxLmhnRZczYwDtb7vtMN/tQbzRMdn2BIaHFOM8KyYF6rov4e
w4j4oQnNKwilDSsamo1s0mMrPo0vm0lc2W9aBG5mGY9NAIztEiNJzq0es71aOn5B
PvtFq40opDsc9xHIg2mIZ5w0S28nx4aUWsFqkKf8fs4HPGe3vHMQvlDII7q+9IPU
qJOUPJGvAgMBAAECggEADd6xK0FzeqXGod7J1PmpnvFUBrgirx9ORFy7AVRmxS7K
L4juDoQUpt6tY5SNpd6CVXuNN8e8Q19R3Eca3TB2fQShuUu2eUAekRLZ+OpYiH6q
42bVX047THbwyDyfcR4f4X5qEEKkcKffbq0VqSuVdZo0YMr0WP4bIYN2+qBzsk+o
+KLPkImsP9UA4nqLLQDJfWQnDD2rRYSbIs3hPa3Bn7R0IgsmMn5jnvgpOjtcxNSt
oeQCIwoTrZ5DJNzidtjwwwDSuLzAoRIjL10bfEG1HSy2RcR48TFca+1jcRZRsO0m
Q/9YO4zAWBRy03tVDF8aZvbEB1EHyfMXCbut8Ac5oQKBgQDoBzhX3rT9Nb4xpoDw
w0KaWjHmPD5bV3Q7mFBhw8gVBoeEd2KZE2m0PQeQCDZRixIFELkZh7iOjHZGjabp
kGOD/qbNHArlq9GqeS4oevg61/8IcqGqPNYK00Mo/DK+jfY6qsLWGRRAAVbGRMoo
RApxIrmoLp4jKDbzTHi3NNUpZwKBgQDMwfFoTGNopI4p7vFmcxDNiTGcDISCEI56
ODTZdRU0C9XODo2aM0XaeX/CmaVK/7enrZHAY8td0+RDdkfMWk8ZmXjm7rio9uo5
n0hj6oVBcG6pLhwwKTEZ257JOXfGEcbisWAWPAFghA1uhMOL4XJOjG2pboDvWEnm
aiYNTyQAeQKBgCKWGO74MpBf93bdM/Evmfj6IuAH8N+avKe5f5njHisMKx0y0o6w
1xvX0Q3GO5qSGWCJ6p2Enp0ZEPRZXx0Hud3OEr0WRgWQRBOeNqQwGFplIg33UGPY
56r7bNJqLYI8FQ0PsTVKzbrwuCebz2qLIedVXslUEZx5/R7tMj1U8cVXAoGAHy/T
Ey2/Xmrh9GUeg5o3Dvc8hSYq8JyQ9vCkrBJ3PkwnLpFs4/W3SAWFfiBk2r2EPZfk
QUdx7EKf296iJPAEaEPF9HabzbB+EHTAU+eekE8Nq9sIFBXSErwuvTtxkMuYXWLi
3cAZ/ZdfbFvwZNfbzzb4ZPwdy1bJOr0kOpa5RxECgYEAwCHol94fviJxVzWaeLi7
ALo6NlQCLGbXT8xGCf1qCcOfvd6YkMa5nMnQgJoJZLR5TqpQsUWLGBu8XbHTTIo8
eNg2dz4CpshWYplnEVGySrD1kkigHeZCNtpDPKC/L48T8ZyTifFdbKqdTU1snsRH
iYKkqCzNvaSOWe+26+wAfo4=
-----END PRIVATE KEY-----
''';

/// SPKI pin of [leafBRsaCertificatePem].
const leafBRsaSpkiPin = 'kXU5bVDLYU9DPDMQi5AlXyr3UdYkwnEry2Tv4dqyiK4=';
