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

