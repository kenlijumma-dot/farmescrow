;; Farmescrow Escrow Manager Contract
;; Manages escrow creation, funding, and completion for farm input transactions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PARAMETERS (err u101))
(define-constant ERR-ESCROW-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-STATE (err u104))
(define-constant ERR-EXPIRED-ESCROW (err u105))
(define-constant ERR-ALREADY-COMPLETED (err u106))
(define-constant ERR-NOT-AUTHORIZED-USER (err u107))
(define-constant ERR-INVALID-AMOUNT (err u108))

;; Minimum escrow amount (10 STX)
(define-constant MIN-ESCROW-AMOUNT u10000000)
;; Maximum escrow duration (90 days in blocks - approximately 129,600 blocks)
(define-constant MAX-ESCROW-DURATION u129600)
;; Platform fee percentage (2% = 200 basis points)
(define-constant PLATFORM-FEE-RATE u200)
;; Verification window (7 days in blocks - approximately 10,080 blocks)
(define-constant VERIFICATION-WINDOW u10080)

;; Escrow states
(define-constant ESCROW-CREATED u1)
(define-constant ESCROW-ACCEPTED u2)
(define-constant ESCROW-DELIVERED u3)
(define-constant ESCROW-VERIFIED u4)
(define-constant ESCROW-COMPLETED u5)
(define-constant ESCROW-DISPUTED u6)
(define-constant ESCROW-REFUNDED u7)

;; Data Variables
(define-data-var next-escrow-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var total-escrows-created uint u0)
(define-data-var total-volume uint u0)

;; Data Maps
;; User registration and verification
(define-map users
  { user: principal }
  {
    registered: bool,
    user-type: (string-ascii 20),
    reputation-score: uint,
    verification-date: uint,
    total-transactions: uint
  }
)

;; Escrow information storage
(define-map escrows
  { escrow-id: uint }
  {
    buyer: principal,
    seller: principal,
    amount: uint,
    description: (string-utf8 200),
    input-type: (string-ascii 50),
    quantity: uint,
    delivery-address: (string-utf8 100),
    created-at: uint,
    deadline: uint,
    state: uint,
    verification-deadline: uint
  }
)

;; Escrow financial details
(define-map escrow-finances
  { escrow-id: uint }
  {
    total-amount: uint,
    platform-fee: uint,
    seller-amount: uint,
    refunded: bool,
    completed: bool
  }
)

;; Escrow participants and verifiers
(define-map escrow-participants
  { escrow-id: uint }
  {
    verifier: (optional principal),
    verifier-assigned: bool,
    buyer-confirmed: bool,
    seller-confirmed: bool,
    verifier-confirmed: bool
  }
)

;; User transaction history
(define-map user-escrows
  { user: principal, escrow-id: uint }
  {
    role: (string-ascii 20),
    transaction-date: uint,
    amount: uint,
    status: uint
  }
)

;; Platform statistics
(define-map platform-stats
  { stat-type: (string-ascii 30) }
  {
    count: uint,
    volume: uint,
    last-updated: uint
  }
)

;; Private Functions

;; Check if user is registered and verified
(define-private (is-registered-user (user principal))
  (match (map-get? users { user: user })
    user-data (get registered user-data)
    false
  )
)

;; Calculate platform fee
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount PLATFORM-FEE-RATE) u10000)
)

;; Calculate seller payout amount
(define-private (calculate-seller-amount (total-amount uint))
  (let ((fee (calculate-platform-fee total-amount)))
    (- total-amount fee)
  )
)

;; Check if escrow has expired
(define-private (is-escrow-expired (escrow-id uint))
  (match (map-get? escrows { escrow-id: escrow-id })
    escrow-data
      (> burn-block-height (get deadline escrow-data))
    true
  )
)

;; Update user statistics
(define-private (update-user-stats (user principal))
  (match (map-get? users { user: user })
    user-data
      (map-set users
        { user: user }
        (merge user-data { total-transactions: (+ (get total-transactions user-data) u1) })
      )
    false
  )
)

;; Record transaction in user history
(define-private (record-user-transaction (user principal) (escrow-id uint) (role (string-ascii 20)) (amount uint) (status uint))
  (map-set user-escrows
    { user: user, escrow-id: escrow-id }
    {
      role: role,
      transaction-date: burn-block-height,
      amount: amount,
      status: status
    }
  )
)

;; Public Functions

;; Register a new user (farmer or supplier)
(define-public (register-user (user-type (string-ascii 20)))
  (begin
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (or (is-eq user-type "farmer") (is-eq user-type "supplier") (is-eq user-type "verifier")) ERR-INVALID-PARAMETERS)
    (asserts! (not (is-registered-user tx-sender)) ERR-INVALID-STATE)
    
    (map-set users
      { user: tx-sender }
      {
        registered: true,
        user-type: user-type,
        reputation-score: u100,
        verification-date: burn-block-height,
        total-transactions: u0
      }
    )
    (ok true)
  )
)

;; Create a new escrow transaction
(define-public (create-escrow
    (seller principal)
    (amount uint)
    (description (string-utf8 200))
    (input-type (string-ascii 50))
    (quantity uint)
    (delivery-address (string-utf8 100))
    (duration-blocks uint)
  )
  (let (
    (escrow-id (var-get next-escrow-id))
    (deadline (+ burn-block-height duration-blocks))
    (platform-fee (calculate-platform-fee amount))
    (seller-amount (calculate-seller-amount amount))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (is-registered-user tx-sender) ERR-NOT-AUTHORIZED-USER)
    (asserts! (is-registered-user seller) ERR-NOT-AUTHORIZED-USER)
    (asserts! (>= amount MIN-ESCROW-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (<= duration-blocks MAX-ESCROW-DURATION) ERR-INVALID-PARAMETERS)
    (asserts! (> (len description) u0) ERR-INVALID-PARAMETERS)
    (asserts! (> quantity u0) ERR-INVALID-PARAMETERS)
    
    ;; Create escrow record
    (map-set escrows
      { escrow-id: escrow-id }
      {
        buyer: tx-sender,
        seller: seller,
        amount: amount,
        description: description,
        input-type: input-type,
        quantity: quantity,
        delivery-address: delivery-address,
        created-at: burn-block-height,
        deadline: deadline,
        state: ESCROW-CREATED,
        verification-deadline: (+ deadline VERIFICATION-WINDOW)
      }
    )
    
    ;; Set financial details
    (map-set escrow-finances
      { escrow-id: escrow-id }
      {
        total-amount: amount,
        platform-fee: platform-fee,
        seller-amount: seller-amount,
        refunded: false,
        completed: false
      }
    )
    
    ;; Initialize participants
    (map-set escrow-participants
      { escrow-id: escrow-id }
      {
        verifier: none,
        verifier-assigned: false,
        buyer-confirmed: false,
        seller-confirmed: false,
        verifier-confirmed: false
      }
    )
    
    ;; Record transaction for buyer
    (record-user-transaction tx-sender escrow-id "buyer" amount ESCROW-CREATED)
    (record-user-transaction seller escrow-id "seller" amount ESCROW-CREATED)
    
    ;; Update counters
    (var-set next-escrow-id (+ escrow-id u1))
    (var-set total-escrows-created (+ (var-get total-escrows-created) u1))
    (var-set total-volume (+ (var-get total-volume) amount))
    
    (ok escrow-id)
  )
)

;; Accept an escrow (seller confirms participation)
(define-public (accept-escrow (escrow-id uint))
  (let (
    (escrow-data (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get seller escrow-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state escrow-data) ESCROW-CREATED) ERR-INVALID-STATE)
    (asserts! (not (is-escrow-expired escrow-id)) ERR-EXPIRED-ESCROW)
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: ESCROW-ACCEPTED })
    )
    
    ;; Update user statistics
    (update-user-stats tx-sender)
    
    (ok true)
  )
)

;; Mark delivery as completed (seller confirms delivery)
(define-public (confirm-delivery (escrow-id uint))
  (let (
    (escrow-data (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get seller escrow-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state escrow-data) ESCROW-ACCEPTED) ERR-INVALID-STATE)
    (asserts! (not (is-escrow-expired escrow-id)) ERR-EXPIRED-ESCROW)
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: ESCROW-DELIVERED })
    )
    
    (ok true)
  )
)

;; Complete escrow transaction (release payment)
(define-public (complete-escrow (escrow-id uint))
  (let (
    (escrow-data (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
    (finance-data (unwrap! (map-get? escrow-finances { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (or (is-eq tx-sender (get buyer escrow-data)) (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state escrow-data) ESCROW-VERIFIED) ERR-INVALID-STATE)
    (asserts! (not (get completed finance-data)) ERR-ALREADY-COMPLETED)
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: ESCROW-COMPLETED })
    )
    
    ;; Update financial record
    (map-set escrow-finances
      { escrow-id: escrow-id }
      (merge finance-data { completed: true })
    )
    
    ;; Update user statistics
    (update-user-stats (get buyer escrow-data))
    (update-user-stats (get seller escrow-data))
    
    (ok true)
  )
)

;; Request refund for expired or disputed escrow
(define-public (request-refund (escrow-id uint))
  (let (
    (escrow-data (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
    (finance-data (unwrap! (map-get? escrow-finances { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get buyer escrow-data)) ERR-UNAUTHORIZED)
    (asserts! (or (is-escrow-expired escrow-id) (is-eq (get state escrow-data) ESCROW-DISPUTED)) ERR-INVALID-STATE)
    (asserts! (not (get refunded finance-data)) ERR-ALREADY-COMPLETED)
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: ESCROW-REFUNDED })
    )
    
    ;; Update financial record
    (map-set escrow-finances
      { escrow-id: escrow-id }
      (merge finance-data { refunded: true })
    )
    
    (ok true)
  )
)

;; Read-only Functions

;; Get escrow information
(define-read-only (get-escrow-info (escrow-id uint))
  (map-get? escrows { escrow-id: escrow-id })
)

;; Get user information
(define-read-only (get-user-info (user principal))
  (map-get? users { user: user })
)

;; Get escrow financial details
(define-read-only (get-escrow-finances (escrow-id uint))
  (map-get? escrow-finances { escrow-id: escrow-id })
)

;; Get escrow participants
(define-read-only (get-escrow-participants (escrow-id uint))
  (map-get? escrow-participants { escrow-id: escrow-id })
)

;; Get user transaction history
(define-read-only (get-user-transaction (user principal) (escrow-id uint))
  (map-get? user-escrows { user: user, escrow-id: escrow-id })
)

;; Get next escrow ID
(define-read-only (get-next-escrow-id)
  (var-get next-escrow-id)
)

;; Get platform statistics
(define-read-only (get-platform-stats)
  {
    total-escrows: (var-get total-escrows-created),
    total-volume: (var-get total-volume),
    contract-paused: (var-get contract-paused)
  }
)

;; Admin Functions

;; Toggle contract pause
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

