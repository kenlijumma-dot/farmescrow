;; Farmescrow Delivery Tracker Contract
;; Tracks delivery status, proof submission, and verification for farm input transactions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-INVALID-PARAMETERS (err u201))
(define-constant ERR-DELIVERY-NOT-FOUND (err u202))
(define-constant ERR-INVALID-STATE (err u203))
(define-constant ERR-PROOF-ALREADY-SUBMITTED (err u204))
(define-constant ERR-VERIFICATION-EXPIRED (err u205))
(define-constant ERR-INSUFFICIENT-VERIFICATIONS (err u206))
(define-constant ERR-ALREADY-VERIFIED (err u207))
(define-constant ERR-INVALID-LOCATION (err u208))

;; Verification requirements
(define-constant MIN-VERIFIERS u1)
(define-constant MAX-VERIFIERS u3)
(define-constant VERIFICATION-THRESHOLD u2)
;; GPS coordinate precision (6 decimal places)
(define-constant GPS-PRECISION u1000000)
;; Maximum delivery distance variance in meters
(define-constant MAX-DELIVERY-DISTANCE u1000)

;; Delivery states
(define-constant DELIVERY-PENDING u1)
(define-constant DELIVERY-IN-TRANSIT u2)
(define-constant DELIVERY-DELIVERED u3)
(define-constant DELIVERY-VERIFIED u4)
(define-constant DELIVERY-DISPUTED u5)
(define-constant DELIVERY-FAILED u6)

;; Proof types
(define-constant PROOF-PHOTO u1)
(define-constant PROOF-SIGNATURE u2)
(define-constant PROOF-GPS u3)
(define-constant PROOF-RECEIPT u4)

;; Data Variables
(define-data-var next-delivery-id uint u1)
(define-data-var total-deliveries uint u0)
(define-data-var total-verified-deliveries uint u0)
(define-data-var contract-paused bool false)

;; Data Maps
;; Delivery tracking information
(define-map deliveries
  { delivery-id: uint }
  {
    escrow-id: uint,
    supplier: principal,
    farmer: principal,
    pickup-location: (string-utf8 100),
    delivery-location: (string-utf8 100),
    pickup-coordinates: { lat: int, lng: int },
    delivery-coordinates: { lat: int, lng: int },
    estimated-delivery: uint,
    actual-delivery: (optional uint),
    state: uint,
    created-at: uint
  }
)

;; Delivery proof submissions
(define-map delivery-proofs
  { delivery-id: uint, proof-type: uint }
  {
    submitter: principal,
    proof-hash: (string-ascii 64),
    proof-description: (string-utf8 200),
    submission-time: uint,
    gps-coordinates: (optional { lat: int, lng: int }),
    verified: bool
  }
)

;; Verification records
(define-map verifications
  { delivery-id: uint, verifier: principal }
  {
    verification-type: (string-ascii 20),
    verdict: bool,
    confidence-score: uint,
    verification-time: uint,
    comments: (string-utf8 200)
  }
)

;; Delivery timeline tracking
(define-map delivery-timeline
  { delivery-id: uint, event-id: uint }
  {
    event-type: (string-ascii 30),
    description: (string-utf8 150),
    timestamp: uint,
    actor: principal,
    location: (optional { lat: int, lng: int })
  }
)

;; Dispute records
(define-map delivery-disputes
  { delivery-id: uint }
  {
    disputer: principal,
    dispute-reason: (string-utf8 200),
    dispute-time: uint,
    resolved: bool,
    resolution: (optional (string-utf8 200))
  }
)

;; Verifier credentials and statistics
(define-map verifiers
  { verifier: principal }
  {
    active: bool,
    specialization: (string-ascii 50),
    total-verifications: uint,
    accuracy-score: uint,
    registration-date: uint
  }
)

;; Data Variables for tracking
(define-data-var next-event-id uint u1)

;; Private Functions

;; Calculate distance between two GPS coordinates (simplified)
(define-private (calculate-distance (coord1 { lat: int, lng: int }) (coord2 { lat: int, lng: int }))
  (let (
    (lat-diff (if (> (get lat coord1) (get lat coord2))
                  (to-uint (- (get lat coord1) (get lat coord2)))
                  (to-uint (- (get lat coord2) (get lat coord1)))))
    (lng-diff (if (> (get lng coord1) (get lng coord2))
                  (to-uint (- (get lng coord1) (get lng coord2)))
                  (to-uint (- (get lng coord2) (get lng coord1)))))
  )
    ;; Simplified distance calculation (not actual GPS distance)
    (+ lat-diff lng-diff)
  )
)

;; Validate GPS coordinates
(define-private (is-valid-coordinates (coordinates { lat: int, lng: int }))
  (and
    (>= (get lat coordinates) (* -90000000))
    (<= (get lat coordinates) 90000000)
    (>= (get lng coordinates) (* -180000000))
    (<= (get lng coordinates) 180000000)
  )
)

;; Check if delivery location is within acceptable range
(define-private (is-delivery-location-valid (delivery-id uint) (actual-coordinates { lat: int, lng: int }))
  (match (map-get? deliveries { delivery-id: delivery-id })
    delivery-data
      (let ((expected-coordinates (get delivery-coordinates delivery-data)))
        (<= (calculate-distance expected-coordinates actual-coordinates) MAX-DELIVERY-DISTANCE)
      )
    false
  )
)

;; Count verified proofs for a delivery
(define-private (count-verified-proofs (delivery-id uint))
  ;; Simplified count - in a real implementation, this would iterate through all proof types
  u1
)

;; Check if delivery has enough verifications
(define-private (has-sufficient-verifications (delivery-id uint))
  (>= (count-verified-proofs delivery-id) VERIFICATION-THRESHOLD)
)

;; Record delivery timeline event
(define-private (record-delivery-event (delivery-id uint) (event-type (string-ascii 30)) (description (string-utf8 150)) (location (optional { lat: int, lng: int })))
  (let ((event-id (var-get next-event-id)))
    (map-set delivery-timeline
      { delivery-id: delivery-id, event-id: event-id }
      {
        event-type: event-type,
        description: description,
        timestamp: burn-block-height,
        actor: tx-sender,
        location: location
      }
    )
    (var-set next-event-id (+ event-id u1))
  )
)

;; Public Functions

;; Create a new delivery tracking record
(define-public (create-delivery
    (escrow-id uint)
    (supplier principal)
    (farmer principal)
    (pickup-location (string-utf8 100))
    (delivery-location (string-utf8 100))
    (pickup-coordinates { lat: int, lng: int })
    (delivery-coordinates { lat: int, lng: int })
    (estimated-delivery-blocks uint)
  )
  (let (
    (delivery-id (var-get next-delivery-id))
    (estimated-delivery (+ burn-block-height estimated-delivery-blocks))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (is-valid-coordinates pickup-coordinates) ERR-INVALID-LOCATION)
    (asserts! (is-valid-coordinates delivery-coordinates) ERR-INVALID-LOCATION)
    (asserts! (> (len pickup-location) u0) ERR-INVALID-PARAMETERS)
    (asserts! (> (len delivery-location) u0) ERR-INVALID-PARAMETERS)
    
    ;; Create delivery record
    (map-set deliveries
      { delivery-id: delivery-id }
      {
        escrow-id: escrow-id,
        supplier: supplier,
        farmer: farmer,
        pickup-location: pickup-location,
        delivery-location: delivery-location,
        pickup-coordinates: pickup-coordinates,
        delivery-coordinates: delivery-coordinates,
        estimated-delivery: estimated-delivery,
        actual-delivery: none,
        state: DELIVERY-PENDING,
        created-at: burn-block-height
      }
    )
    
    ;; Record creation event
    (record-delivery-event delivery-id "DELIVERY_CREATED" u"Delivery tracking initiated" (some pickup-coordinates))
    
    ;; Update counters
    (var-set next-delivery-id (+ delivery-id u1))
    (var-set total-deliveries (+ (var-get total-deliveries) u1))
    
    (ok delivery-id)
  )
)

;; Update delivery status to in-transit
(define-public (start-delivery (delivery-id uint) (current-location { lat: int, lng: int }))
  (let (
    (delivery-data (unwrap! (map-get? deliveries { delivery-id: delivery-id }) ERR-DELIVERY-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get supplier delivery-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state delivery-data) DELIVERY-PENDING) ERR-INVALID-STATE)
    (asserts! (is-valid-coordinates current-location) ERR-INVALID-LOCATION)
    
    ;; Update delivery state
    (map-set deliveries
      { delivery-id: delivery-id }
      (merge delivery-data { state: DELIVERY-IN-TRANSIT })
    )
    
    ;; Record transit event
    (record-delivery-event delivery-id "DELIVERY_STARTED" u"Farm inputs picked up and in transit" (some current-location))
    
    (ok true)
  )
)

;; Submit proof of delivery
(define-public (submit-delivery-proof
    (delivery-id uint)
    (proof-type uint)
    (proof-hash (string-ascii 64))
    (proof-description (string-utf8 200))
    (gps-coordinates (optional { lat: int, lng: int }))
  )
  (let (
    (delivery-data (unwrap! (map-get? deliveries { delivery-id: delivery-id }) ERR-DELIVERY-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get supplier delivery-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state delivery-data) DELIVERY-IN-TRANSIT) ERR-INVALID-STATE)
    (asserts! (>= proof-type PROOF-PHOTO) ERR-INVALID-PARAMETERS)
    (asserts! (<= proof-type PROOF-RECEIPT) ERR-INVALID-PARAMETERS)
    (asserts! (> (len proof-hash) u0) ERR-INVALID-PARAMETERS)
    
    ;; Validate GPS coordinates if provided
    (match gps-coordinates
      coords (asserts! (is-valid-coordinates coords) ERR-INVALID-LOCATION)
      true
    )
    
    ;; Check if proof already exists
    (asserts! (is-none (map-get? delivery-proofs { delivery-id: delivery-id, proof-type: proof-type })) ERR-PROOF-ALREADY-SUBMITTED)
    
    ;; Submit proof
    (map-set delivery-proofs
      { delivery-id: delivery-id, proof-type: proof-type }
      {
        submitter: tx-sender,
        proof-hash: proof-hash,
        proof-description: proof-description,
        submission-time: burn-block-height,
        gps-coordinates: gps-coordinates,
        verified: false
      }
    )
    
    ;; Update delivery state to delivered if GPS proof is valid
    (begin
      (if (and (is-eq proof-type PROOF-GPS) (is-some gps-coordinates))
        (let ((coords (unwrap-panic gps-coordinates)))
          (if (is-delivery-location-valid delivery-id coords)
            (begin
              (map-set deliveries
                { delivery-id: delivery-id }
                (merge delivery-data { 
                  state: DELIVERY-DELIVERED,
                  actual-delivery: (some burn-block-height)
                })
              )
              (record-delivery-event delivery-id "DELIVERY_COMPLETED" u"Farm inputs delivered to destination" (some coords))
            )
            true
          )
        )
        true
      )
      (ok true)
    )
  )
)

;; Verify delivery proof (by authorized verifier)
(define-public (verify-delivery-proof
    (delivery-id uint)
    (proof-type uint)
    (verdict bool)
    (confidence-score uint)
    (comments (string-utf8 200))
  )
  (let (
    (delivery-data (unwrap! (map-get? deliveries { delivery-id: delivery-id }) ERR-DELIVERY-NOT-FOUND))
    (proof-data (unwrap! (map-get? delivery-proofs { delivery-id: delivery-id, proof-type: proof-type }) ERR-DELIVERY-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (>= (get state delivery-data) DELIVERY-DELIVERED) ERR-INVALID-STATE)
    (asserts! (<= confidence-score u100) ERR-INVALID-PARAMETERS)
    
    ;; Record verification
    (map-set verifications
      { delivery-id: delivery-id, verifier: tx-sender }
      {
        verification-type: "PROOF_VERIFICATION",
        verdict: verdict,
        confidence-score: confidence-score,
        verification-time: burn-block-height,
        comments: comments
      }
    )
    
    ;; Update proof as verified if verdict is positive
    (if verdict
      (begin
        (map-set delivery-proofs
          { delivery-id: delivery-id, proof-type: proof-type }
          (merge proof-data { verified: true })
        )
        true
      )
      true
    )
    
    ;; Check if delivery can be marked as fully verified
    (if (and verdict (has-sufficient-verifications delivery-id))
      (begin
        (map-set deliveries
          { delivery-id: delivery-id }
          (merge delivery-data { state: DELIVERY-VERIFIED })
        )
        (var-set total-verified-deliveries (+ (var-get total-verified-deliveries) u1))
        (record-delivery-event delivery-id "DELIVERY_VERIFIED" u"All delivery proofs verified successfully" none)
        true
      )
      true
    )
    
    (ok true)
  )
)

;; Raise a delivery dispute
(define-public (raise-dispute (delivery-id uint) (dispute-reason (string-utf8 200)))
  (let (
    (delivery-data (unwrap! (map-get? deliveries { delivery-id: delivery-id }) ERR-DELIVERY-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (or (is-eq tx-sender (get farmer delivery-data)) (is-eq tx-sender (get supplier delivery-data))) ERR-UNAUTHORIZED)
    (asserts! (< (get state delivery-data) DELIVERY-VERIFIED) ERR-INVALID-STATE)
    (asserts! (> (len dispute-reason) u0) ERR-INVALID-PARAMETERS)
    
    ;; Create dispute record
    (map-set delivery-disputes
      { delivery-id: delivery-id }
      {
        disputer: tx-sender,
        dispute-reason: dispute-reason,
        dispute-time: burn-block-height,
        resolved: false,
        resolution: none
      }
    )
    
    ;; Update delivery state
    (map-set deliveries
      { delivery-id: delivery-id }
      (merge delivery-data { state: DELIVERY-DISPUTED })
    )
    
    ;; Record dispute event
    (record-delivery-event delivery-id "DISPUTE_RAISED" u"Delivery dispute raised by participant" none)
    
    (ok true)
  )
)

;; Read-only Functions

;; Get delivery information
(define-read-only (get-delivery-info (delivery-id uint))
  (map-get? deliveries { delivery-id: delivery-id })
)

;; Get delivery proof
(define-read-only (get-delivery-proof (delivery-id uint) (proof-type uint))
  (map-get? delivery-proofs { delivery-id: delivery-id, proof-type: proof-type })
)

;; Get verification record
(define-read-only (get-verification (delivery-id uint) (verifier principal))
  (map-get? verifications { delivery-id: delivery-id, verifier: verifier })
)

;; Get delivery timeline event
(define-read-only (get-timeline-event (delivery-id uint) (event-id uint))
  (map-get? delivery-timeline { delivery-id: delivery-id, event-id: event-id })
)

;; Get delivery dispute
(define-read-only (get-delivery-dispute (delivery-id uint))
  (map-get? delivery-disputes { delivery-id: delivery-id })
)

;; Get verifier info
(define-read-only (get-verifier-info (verifier principal))
  (map-get? verifiers { verifier: verifier })
)

;; Get delivery statistics
(define-read-only (get-delivery-stats)
  {
    total-deliveries: (var-get total-deliveries),
    total-verified: (var-get total-verified-deliveries),
    success-rate: (if (> (var-get total-deliveries) u0)
                    (/ (* (var-get total-verified-deliveries) u100) (var-get total-deliveries))
                    u0)
  }
)

;; Admin Functions

;; Register a new verifier
(define-public (register-verifier (verifier principal) (specialization (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> (len specialization) u0) ERR-INVALID-PARAMETERS)
    
    (map-set verifiers
      { verifier: verifier }
      {
        active: true,
        specialization: specialization,
        total-verifications: u0,
        accuracy-score: u100,
        registration-date: burn-block-height
      }
    )
    
    (ok true)
  )
)

;; Toggle contract pause
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

