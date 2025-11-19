;; Soulbound Academic Credentials Contract
;; A comprehensive system for issuing and managing non-transferable academic certificates as NFTs
;; Includes certificate verification, institution registry, and achievement tracking

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-ISSUED (err u101))
(define-constant ERR-CERTIFICATE-NOT-FOUND (err u102))
(define-constant ERR-INVALID-INSTITUTION (err u103))
(define-constant ERR-CERTIFICATE-REVOKED (err u104))
(define-constant ERR-INVALID-GRADE (err u105))
(define-constant ERR-INSTITUTION-NOT-FOUND (err u106))
(define-constant ERR-ACHIEVEMENT-NOT-FOUND (err u107))
(define-constant ERR-INVALID-ACHIEVEMENT-TYPE (err u108))
(define-constant ERR-VERIFICATION-LOG-NOT-FOUND (err u109))
(define-constant ERR-INVALID-VERIFICATION-PURPOSE (err u110))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; NFT trait for certificates
(define-non-fungible-token academic-certificate uint)

;; Certificate status enum
(define-constant CERT-ACTIVE u1)
(define-constant CERT-REVOKED u2)
(define-constant CERT-SUSPENDED u3)

;; Error for suspension/expiration
(define-constant ERR-CREDENTIAL-EXPIRED (err u111))
(define-constant ERR-CREDENTIAL-SUSPENDED (err u112))

;; Achievement types for additional tracking
(define-constant ACHIEVEMENT-HONOR-ROLL u1)
(define-constant ACHIEVEMENT-DEAN-LIST u2)
(define-constant ACHIEVEMENT-MAGNA-CUM-LAUDE u3)
(define-constant ACHIEVEMENT-SUMMA-CUM-LAUDE u4)
(define-constant ACHIEVEMENT-RESEARCH-EXCELLENCE u5)

;; Verification purposes for audit trail
(define-constant VERIFICATION-EMPLOYMENT u1)
(define-constant VERIFICATION-ACADEMIC-TRANSFER u2)
(define-constant VERIFICATION-LICENSING u3)
(define-constant VERIFICATION-BACKGROUND-CHECK u4)
(define-constant VERIFICATION-GENERAL-INQUIRY u5)

;; Data variables
(define-data-var next-certificate-id uint u1)
(define-data-var next-institution-id uint u1)
(define-data-var next-achievement-id uint u1)
(define-data-var next-verification-log-id uint u1)

;; Suspension tracking map
(define-map certificate-suspensions
  uint
  {
    suspended-date: uint,
    expiration-date: uint,
    reason: (string-ascii 200)
  }
)

;; Institution registry map
(define-map institutions
  uint ;; institution-id
  {
    name: (string-ascii 100),
    admin: principal,
    verified: bool,
    registration-date: uint
  }
)

;; Certificate data map
(define-map certificates
  uint ;; certificate-id
  {
    recipient: principal,
    institution-id: uint,
    degree-type: (string-ascii 50),
    major: (string-ascii 100),
    gpa: uint, ;; multiplied by 100 (e.g., 350 = 3.50 GPA)
    graduation-date: uint,
    issue-date: uint,
    status: uint,
    ipfs-hash: (string-ascii 64) ;; for additional certificate data
  }
)

;; Student achievements map (independent feature)
(define-map student-achievements
  uint ;; achievement-id
  {
    student: principal,
    institution-id: uint,
    achievement-type: uint,
    semester: (string-ascii 20),
    academic-year: uint,
    award-date: uint,
    description: (string-ascii 200)
  }
)

;; Certificate verification logs (independent feature)
(define-map verification-logs
  uint ;; verification-log-id
  {
    certificate-id: uint,
    verifier: principal,
    verification-date: uint,
    purpose: uint,
    organization: (string-ascii 100),
    notes: (string-ascii 200),
    verification-result: bool
  }
)

;; Maps for quick lookups
(define-map student-certificates
  principal ;; student
  (list 50 uint) ;; certificate-ids
)

(define-map institution-certificates
  uint ;; institution-id
  (list 1000 uint) ;; certificate-ids
)

(define-map student-achievement-list
  principal ;; student
  (list 100 uint) ;; achievement-ids
)

(define-map certificate-verification-logs
  uint ;; certificate-id
  (list 200 uint) ;; verification-log-ids
)

(define-map verifier-logs
  principal ;; verifier
  (list 500 uint) ;; verification-log-ids
)

;; Public functions

;; Register a new academic institution
(define-public (register-institution (name (string-ascii 100)))
  (let
    (
      (institution-id (var-get next-institution-id))
    )
    (if (is-eq tx-sender CONTRACT-OWNER)
      (begin
        (map-set institutions
          institution-id
          {
            name: name,
            admin: tx-sender,
            verified: true,
            registration-date: burn-block-height
          }
        )
        (var-set next-institution-id (+ institution-id u1))
        (ok institution-id)
      )
      ERR-NOT-AUTHORIZED
    )
  )
)

;; Update institution admin (only contract owner)
(define-public (update-institution-admin (institution-id uint) (new-admin principal))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (match (map-get? institutions institution-id)
      institution-data
      (begin
        (map-set institutions
          institution-id
          (merge institution-data { admin: new-admin })
        )
        (ok true)
      )
      ERR-INSTITUTION-NOT-FOUND
    )
    ERR-NOT-AUTHORIZED
  )
)

;; Issue a soulbound certificate
(define-public (issue-certificate
  (recipient principal)
  (institution-id uint)
  (degree-type (string-ascii 50))
  (major (string-ascii 100))
  (gpa uint)
  (graduation-date uint)
  (ipfs-hash (string-ascii 64))
)
  (let
    (
      (certificate-id (var-get next-certificate-id))
      (institution-data (unwrap! (map-get? institutions institution-id) ERR-INVALID-INSTITUTION))
    )
    ;; Only institution admin can issue certificates
    (if (and 
         (is-eq tx-sender (get admin institution-data))
         (get verified institution-data)
         (<= gpa u400) ;; Max GPA 4.00
       )
      (begin
        ;; Mint the NFT
        (unwrap! (nft-mint? academic-certificate certificate-id recipient) (err u999))
        
        ;; Store certificate data
        (map-set certificates
          certificate-id
          {
            recipient: recipient,
            institution-id: institution-id,
            degree-type: degree-type,
            major: major,
            gpa: gpa,
            graduation-date: graduation-date,
            issue-date: burn-block-height,
            status: CERT-ACTIVE,
            ipfs-hash: ipfs-hash
          }
        )
        
        ;; Update student certificates list
        (map-set student-certificates
          recipient
          (unwrap! (as-max-len? (append (default-to (list) (map-get? student-certificates recipient)) certificate-id) u50) (err u998))
        )
        
        ;; Update institution certificates list
        (map-set institution-certificates
          institution-id
          (unwrap! (as-max-len? (append (default-to (list) (map-get? institution-certificates institution-id)) certificate-id) u1000) (err u997))
        )
        
        (var-set next-certificate-id (+ certificate-id u1))
        (ok certificate-id)
      )
      (if (> gpa u400)
        ERR-INVALID-GRADE
        (if (not (get verified institution-data))
          ERR-INVALID-INSTITUTION
          ERR-NOT-AUTHORIZED
        )
      )
    )
  )
)

;; Award student achievement (independent feature)
(define-public (award-achievement
  (student principal)
  (institution-id uint)
  (achievement-type uint)
  (semester (string-ascii 20))
  (academic-year uint)
  (description (string-ascii 200))
)
  (let
    (
      (achievement-id (var-get next-achievement-id))
      (institution-data (unwrap! (map-get? institutions institution-id) ERR-INVALID-INSTITUTION))
    )
    ;; Only institution admin can award achievements
    (if (and 
         (is-eq tx-sender (get admin institution-data))
         (get verified institution-data)
         (<= achievement-type u5)
         (>= achievement-type u1)
       )
      (begin
        ;; Store achievement data
        (map-set student-achievements
          achievement-id
          {
            student: student,
            institution-id: institution-id,
            achievement-type: achievement-type,
            semester: semester,
            academic-year: academic-year,
            award-date: burn-block-height,
            description: description
          }
        )
        
        ;; Update student achievements list
        (map-set student-achievement-list
          student
          (unwrap! (as-max-len? (append (default-to (list) (map-get? student-achievement-list student)) achievement-id) u100) (err u996))
        )
        
        (var-set next-achievement-id (+ achievement-id u1))
        (ok achievement-id)
      )
      (if (or (> achievement-type u5) (< achievement-type u1))
        ERR-INVALID-ACHIEVEMENT-TYPE
        (if (not (get verified institution-data))
          ERR-INVALID-INSTITUTION
          ERR-NOT-AUTHORIZED
        )
      )
    )
  )
)

;; Log certificate verification attempt (independent feature)
(define-public (log-verification
  (certificate-id uint)
  (purpose uint)
  (organization (string-ascii 100))
  (notes (string-ascii 200))
)
  (let
    (
      (log-id (var-get next-verification-log-id))
      (certificate-exists (is-some (map-get? certificates certificate-id)))
      (verification-result (match (map-get? certificates certificate-id)
        cert-data (is-eq (get status cert-data) CERT-ACTIVE)
        false
      ))
    )
    (if (and
         certificate-exists
         (<= purpose u5)
         (>= purpose u1)
       )
      (begin
        ;; Store verification log
        (map-set verification-logs
          log-id
          {
            certificate-id: certificate-id,
            verifier: tx-sender,
            verification-date: burn-block-height,
            purpose: purpose,
            organization: organization,
            notes: notes,
            verification-result: verification-result
          }
        )
        
        ;; Update certificate verification logs
        (map-set certificate-verification-logs
          certificate-id
          (unwrap! (as-max-len? (append (default-to (list) (map-get? certificate-verification-logs certificate-id)) log-id) u200) (err u995))
        )
        
        ;; Update verifier logs
        (map-set verifier-logs
          tx-sender
          (unwrap! (as-max-len? (append (default-to (list) (map-get? verifier-logs tx-sender)) log-id) u500) (err u994))
        )
        
        (var-set next-verification-log-id (+ log-id u1))
        (ok {
          log-id: log-id,
          verification-result: verification-result,
          certificate-status: (if verification-result "active" "inactive")
        })
      )
      (if (or (> purpose u5) (< purpose u1))
        ERR-INVALID-VERIFICATION-PURPOSE
        ERR-CERTIFICATE-NOT-FOUND
      )
    )
  )
)

;; Revoke a certificate (only institution admin)
(define-public (revoke-certificate (certificate-id uint))
  (let
    (
      (certificate-data (unwrap! (map-get? certificates certificate-id) ERR-CERTIFICATE-NOT-FOUND))
      (institution-data (unwrap! (map-get? institutions (get institution-id certificate-data)) ERR-INVALID-INSTITUTION))
    )
    (if (is-eq tx-sender (get admin institution-data))
      (begin
        (map-set certificates
          certificate-id
          (merge certificate-data { status: CERT-REVOKED })
        )
        (ok true)
      )
      ERR-NOT-AUTHORIZED
    )
  )
)

(define-public (suspend-certificate (certificate-id uint) (expiration-date uint) (reason (string-ascii 200)))
  (let
    (
      (certificate-data (unwrap! (map-get? certificates certificate-id) ERR-CERTIFICATE-NOT-FOUND))
      (institution-data (unwrap! (map-get? institutions (get institution-id certificate-data)) ERR-INVALID-INSTITUTION))
      (current-status (get status certificate-data))
    )
    (if (and
         (is-eq tx-sender (get admin institution-data))
         (is-eq current-status CERT-ACTIVE)
       )
      (begin
        (map-set certificates
          certificate-id
          (merge certificate-data { status: CERT-SUSPENDED })
        )
        (map-set certificate-suspensions
          certificate-id
          {
            suspended-date: burn-block-height,
            expiration-date: expiration-date,
            reason: reason
          }
        )
        (ok true)
      )
      ERR-NOT-AUTHORIZED
    )
  )
)

(define-public (unsuspend-certificate (certificate-id uint))
  (let
    (
      (certificate-data (unwrap! (map-get? certificates certificate-id) ERR-CERTIFICATE-NOT-FOUND))
      (institution-data (unwrap! (map-get? institutions (get institution-id certificate-data)) ERR-INVALID-INSTITUTION))
      (current-status (get status certificate-data))
    )
    (if (and
         (is-eq tx-sender (get admin institution-data))
         (is-eq current-status CERT-SUSPENDED)
       )
      (begin
        (map-set certificates
          certificate-id
          (merge certificate-data { status: CERT-ACTIVE })
        )
        (map-delete certificate-suspensions certificate-id)
        (ok true)
      )
      ERR-NOT-AUTHORIZED
    )
  )
)

;; Read-only functions

;; Get certificate details
(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates certificate-id)
)

;; Get institution details
(define-read-only (get-institution (institution-id uint))
  (map-get? institutions institution-id)
)

;; Get student achievement details
(define-read-only (get-achievement (achievement-id uint))
  (map-get? student-achievements achievement-id)
)

;; Get all certificates for a student
(define-read-only (get-student-certificates (student principal))
  (default-to (list) (map-get? student-certificates student))
)

;; Get all achievements for a student
(define-read-only (get-student-achievements (student principal))
  (default-to (list) (map-get? student-achievement-list student))
)

;; Get all certificates issued by an institution
(define-read-only (get-institution-certificates (institution-id uint))
  (default-to (list) (map-get? institution-certificates institution-id))
)

;; Verify certificate authenticity
(define-read-only (verify-certificate (certificate-id uint))
  (match (map-get? certificates certificate-id)
    certificate-data
    (ok {
      valid: (is-eq (get status certificate-data) CERT-ACTIVE),
      recipient: (get recipient certificate-data),
      institution-id: (get institution-id certificate-data),
      issue-date: (get issue-date certificate-data),
      status: (get status certificate-data)
    })
    ERR-CERTIFICATE-NOT-FOUND
  )
)

;; Get certificate owner (NFT trait requirement)
(define-read-only (get-owner (certificate-id uint))
  (ok (nft-get-owner? academic-certificate certificate-id))
)

;; Get last token ID
(define-read-only (get-last-token-id)
  (ok (- (var-get next-certificate-id) u1))
)

;; Get next certificate ID
(define-read-only (get-next-certificate-id)
  (var-get next-certificate-id)
)

;; Get certificate statistics for an institution
(define-read-only (get-institution-stats (institution-id uint))
  (let
    (
      (cert-list (default-to (list) (map-get? institution-certificates institution-id)))
    )
    (ok {
      total-certificates: (len cert-list),
      institution-id: institution-id
    })
  )
)

;; Calculate student GPA average from all certificates
(define-read-only (calculate-student-gpa (student principal))
  (let
    (
      (cert-ids (default-to (list) (map-get? student-certificates student)))
    )
    ;; This would need a more complex implementation to actually calculate GPA
    ;; For now, return the count of certificates
    (ok (len cert-ids))
  )
)

;; Get verification log details
(define-read-only (get-verification-log (log-id uint))
  (map-get? verification-logs log-id)
)

;; Get all verification logs for a certificate
(define-read-only (get-certificate-verification-history (certificate-id uint))
  (default-to (list) (map-get? certificate-verification-logs certificate-id))
)

;; Get all verification logs by a verifier
(define-read-only (get-verifier-history (verifier principal))
  (default-to (list) (map-get? verifier-logs verifier))
)

;; Get verification statistics for a certificate
(define-read-only (get-certificate-verification-stats (certificate-id uint))
  (let
    (
      (log-ids (default-to (list) (map-get? certificate-verification-logs certificate-id)))
    )
    (ok {
      total-verifications: (len log-ids),
      certificate-id: certificate-id,
      last-verification: (if (> (len log-ids) u0)
                            (some (element-at? log-ids (- (len log-ids) u1)))
                            none)
    })
  )
)

;; Get verification purpose name (helper function)
(define-read-only (get-verification-purpose-name (purpose uint))
  (if (is-eq purpose VERIFICATION-EMPLOYMENT) (ok "Employment Verification")
  (if (is-eq purpose VERIFICATION-ACADEMIC-TRANSFER) (ok "Academic Transfer")
  (if (is-eq purpose VERIFICATION-LICENSING) (ok "Professional Licensing")
  (if (is-eq purpose VERIFICATION-BACKGROUND-CHECK) (ok "Background Check")
  (if (is-eq purpose VERIFICATION-GENERAL-INQUIRY) (ok "General Inquiry")
      ERR-INVALID-VERIFICATION-PURPOSE)))))
)

;; Get verification trends for an institution
(define-read-only (get-institution-verification-trends (institution-id uint))
  (let
    (
      (cert-ids (default-to (list) (map-get? institution-certificates institution-id)))
      (total-certs (len cert-ids))
    )
    ;; Calculate basic verification metrics
    (ok {
      institution-id: institution-id,
      total-certificates: total-certs,
      certificates-with-verifications: u0 ;; Would need complex implementation
    })
  )
)

(define-read-only (get-suspension-details (certificate-id uint))
  (map-get? certificate-suspensions certificate-id)
)

(define-read-only (check-credential-validity (certificate-id uint))
  (match (map-get? certificates certificate-id)
    certificate-data
    (let
      (
        (status (get status certificate-data))
        (suspension-info (map-get? certificate-suspensions certificate-id))
      )
      (if (is-eq status CERT-REVOKED)
        (ok {
          is-valid: false,
          reason: "Certificate revoked"
        })
        (if (is-eq status CERT-SUSPENDED)
          (match suspension-info
            susp-data
            (let
              (
                (expiration (get expiration-date susp-data))
              )
              (if (> burn-block-height expiration)
                (ok {
                  is-valid: false,
                  reason: "Suspension expired"
                })
                (ok {
                  is-valid: false,
                  reason: "Credential suspended"
                })
              )
            )
            (ok {
              is-valid: false,
              reason: "Suspension data missing"
            })
          )
          (ok {
            is-valid: true,
            reason: "Credential active"
          })
        )
      )
    )
    ERR-CERTIFICATE-NOT-FOUND
  )
)

;; Private functions (none needed for this implementation)

;; Transfer function override - soulbound tokens cannot be transferred
(define-public (transfer (id uint) (sender principal) (recipient principal))
  ERR-NOT-AUTHORIZED ;; Soulbound - no transfers allowed
)
