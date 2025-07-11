(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-institution-exists (err u102))
(define-constant err-invalid-institution (err u103))
(define-constant err-certificate-exists (err u104))
(define-constant err-certificate-not-found (err u105))
(define-constant err-not-certificate-owner (err u106))

(define-non-fungible-token soulbound-certificate uint)

(define-map institutions principal 
  {
    name: (string-ascii 50),
    website: (string-ascii 100),
    verified: bool,
    registration-height: uint
  }
)

(define-map certificates uint 
  {
    institution: principal,
    recipient: principal,
    title: (string-ascii 100),
    description: (string-ascii 200),
    issue-date: uint,
    grade: (optional (string-ascii 2)),
    metadata-url: (string-ascii 200)
  }
)

(define-data-var certificate-counter uint u0)

(define-public (register-institution (name (string-ascii 50)) (website (string-ascii 100)))
  (let ((institution-data (map-get? institutions tx-sender)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none institution-data) err-institution-exists)
    (ok (map-set institutions tx-sender
      {
        name: name,
        website: website,
        verified: true,
        registration-height: stacks-block-height
      }))))
(define-public (update-institution (institution principal) (name (string-ascii 50)) (website (string-ascii 100)))
  (let ((institution-data (map-get? institutions institution)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some institution-data) err-invalid-institution)
    (ok (map-set institutions institution
      (merge (unwrap-panic institution-data)
        {
          name: name,
          website: website
        })))))

(define-public (issue-certificate 
    (recipient principal)
    (title (string-ascii 100))
    (description (string-ascii 200))
    (grade (optional (string-ascii 2)))
    (metadata-url (string-ascii 200)))
  (let 
    (
      (institution-data (map-get? institutions tx-sender))
      (certificate-id (+ (var-get certificate-counter) u1))
    )
    (asserts! (is-some institution-data) err-invalid-institution)
    (asserts! (get verified (unwrap-panic institution-data)) err-not-authorized)
    (try! (nft-mint? soulbound-certificate certificate-id recipient))
    (map-set certificates certificate-id
      {
        institution: tx-sender,
        recipient: recipient,
        title: title,
        description: description,
        issue-date: stacks-block-height,
        grade: grade,
        metadata-url: metadata-url
      })
    (var-set certificate-counter certificate-id)
    (ok certificate-id)))
(define-read-only (get-certificate (certificate-id uint))
  (match (map-get? certificates certificate-id)
    certificate (ok certificate)
    err-certificate-not-found))

(define-read-only (get-institution (institution principal))
  (match (map-get? institutions institution)
    institution-data (ok institution-data)
    err-invalid-institution))

(define-read-only (get-certificate-owner (certificate-id uint))
  (match (nft-get-owner? soulbound-certificate certificate-id)
    owner (ok owner)
    err-certificate-not-found))

(define-read-only (has-certificate (certificate-id uint) (owner principal))
  (match (nft-get-owner? soulbound-certificate certificate-id)
    certificate-owner (ok (is-eq certificate-owner owner))
    err-certificate-not-found))

(define-public (verify-certificate (certificate-id uint) (expected-recipient principal))
  (match (map-get? certificates certificate-id)
    certificate (ok (is-eq (get recipient certificate) expected-recipient))
    err-certificate-not-found))

(define-public (transfer (certificate-id uint) (sender principal) (recipient principal))
  (err u1)) ;; Transfers not allowed - soulbound

(define-constant err-certificate-revoked (err u107))
(define-constant err-already-revoked (err u108))

(define-map certificate-revocations uint 
  {
    revoked: bool,
    revocation-date: uint,
    reason: (string-ascii 100),
    revoked-by: principal
  }
)

(define-public (revoke-certificate (certificate-id uint) (reason (string-ascii 100)))
  (let 
    (
      (certificate-data (map-get? certificates certificate-id))
      (revocation-data (map-get? certificate-revocations certificate-id))
    )
    (asserts! (is-some certificate-data) err-certificate-not-found)
    (asserts! (is-eq tx-sender (get institution (unwrap-panic certificate-data))) err-not-authorized)
    (asserts! (or (is-none revocation-data) (not (get revoked (unwrap-panic revocation-data)))) err-already-revoked)
    (ok (map-set certificate-revocations certificate-id
      {
        revoked: true,
        revocation-date: stacks-block-height,
        reason: reason,
        revoked-by: tx-sender
      }))))

(define-read-only (is-certificate-revoked (certificate-id uint))
  (match (map-get? certificate-revocations certificate-id)
    revocation-data (ok (get revoked revocation-data))
    (ok false)))

(define-read-only (get-revocation-details (certificate-id uint))
  (match (map-get? certificate-revocations certificate-id)
    revocation-data (ok revocation-data)
    err-certificate-not-found))

(define-public (verify-certificate-with-revocation (certificate-id uint) (expected-recipient principal))
  (let 
    (
      (certificate-data (map-get? certificates certificate-id))
      (revocation-data (map-get? certificate-revocations certificate-id))
    )
    (asserts! (is-some certificate-data) err-certificate-not-found)
    (asserts! (or (is-none revocation-data) (not (get revoked (unwrap-panic revocation-data)))) err-certificate-revoked)
    (ok (is-eq (get recipient (unwrap-panic certificate-data)) expected-recipient))))

(define-constant err-invalid-category (err u109))

(define-map certificate-categories uint (string-ascii 20))

(define-map recipient-certificates principal (list 100 uint))

(define-map category-certificates (string-ascii 20) (list 1000 uint))

(define-public (issue-certificate-with-category
    (recipient principal)
    (title (string-ascii 100))
    (description (string-ascii 200))
    (grade (optional (string-ascii 2)))
    (metadata-url (string-ascii 200))
    (category (string-ascii 20)))
  (let 
    (
      (institution-data (map-get? institutions tx-sender))
      (certificate-id (+ (var-get certificate-counter) u1))
      (recipient-certs (default-to (list) (map-get? recipient-certificates recipient)))
      (category-certs (default-to (list) (map-get? category-certificates category)))
    )
    (asserts! (is-some institution-data) err-invalid-institution)
    (asserts! (get verified (unwrap-panic institution-data)) err-not-authorized)
    (try! (nft-mint? soulbound-certificate certificate-id recipient))
    (map-set certificates certificate-id
      {
        institution: tx-sender,
        recipient: recipient,
        title: title,
        description: description,
        issue-date: stacks-block-height,
        grade: grade,
        metadata-url: metadata-url
      })
    (map-set certificate-categories certificate-id category)
    (map-set recipient-certificates recipient (unwrap-panic (as-max-len? (append recipient-certs certificate-id) u100)))
    (map-set category-certificates category (unwrap-panic (as-max-len? (append category-certs certificate-id) u1000)))
    (var-set certificate-counter certificate-id)
    (ok certificate-id)))

(define-read-only (get-certificate-category (certificate-id uint))
  (match (map-get? certificate-categories certificate-id)
    category (ok category)
    err-certificate-not-found))

(define-read-only (get-certificates-by-recipient (recipient principal))
  (match (map-get? recipient-certificates recipient)
    cert-list (ok cert-list)
    (ok (list))))

(define-read-only (get-certificates-by-category (category (string-ascii 20)))
  (match (map-get? category-certificates category)
    cert-list (ok cert-list)
    (ok (list))))

(define-read-only (get-recipient-certificates-by-category (recipient principal) (category (string-ascii 20)))
  (let 
    (
      (recipient-certs (default-to (list) (map-get? recipient-certificates recipient)))
    )
    (ok (filter check-certificate-category recipient-certs))))

(define-private (check-certificate-category (certificate-id uint))
  (match (map-get? certificate-categories certificate-id)
    cert-category true
    false))