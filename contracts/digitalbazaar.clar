;; DigitalBazaar - Decentralized NFT & Digital Asset Marketplace
;; A comprehensive marketplace for trading digital assets with escrow and royalty features

;; Constants
(define-constant MARKETPLACE-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-LISTING-NOT-FOUND (err u301))
(define-constant ERR-INVALID-PRICE (err u302))
(define-constant ERR-ALREADY-LISTED (err u303))
(define-constant ERR-LISTING-EXPIRED (err u304))
(define-constant ERR-ALREADY-SOLD (err u305))
(define-constant ERR-INSUFFICIENT-FUNDS (err u306))
(define-constant ERR-INVALID-ASSET (err u307))
(define-constant ERR-ROYALTY-TOO-HIGH (err u308))
(define-constant ERR-MARKETPLACE-CLOSED (err u309))
(define-constant ERR-SELF-PURCHASE (err u310))

;; Configuration
(define-constant LISTING-DURATION u1008) ;; ~7 days in blocks
(define-constant MIN-PRICE u1000) ;; Minimum listing price
(define-constant MARKETPLACE-FEE u250) ;; 2.5% marketplace fee (basis points)
(define-constant MAX-ROYALTY u1000) ;; 10% maximum royalty (basis points)
(define-constant ESCROW-PERIOD u144) ;; ~24 hours escrow period

;; State Variables
(define-data-var platform-treasury uint u0)
(define-data-var listing-counter uint u0)
(define-data-var marketplace-active bool true)
(define-data-var total-volume uint u0)

;; Storage Maps
(define-map asset-listings
    uint
    {
        asset-id: (string-ascii 64),
        seller: principal,
        price: uint,
        listed-at: uint,
        expires-at: uint,
        sold: bool,
        cancelled: bool,
        buyer: (optional principal),
        royalty-recipient: (optional principal),
        royalty-percentage: uint,
        category: (string-ascii 32)
    }
)

(define-map user-balances principal uint)
(define-map asset-ownership (string-ascii 64) principal)
(define-map escrow-holds
    {listing-id: uint, buyer: principal}
    {amount: uint, release-at: uint}
)

(define-map user-ratings principal {total-rating: uint, rating-count: uint})

;; Authorization helpers
(define-private (is-marketplace-owner)
    (is-eq tx-sender MARKETPLACE-OWNER)
)

(define-private (owns-asset (asset-id (string-ascii 64)))
    (is-eq (some tx-sender) (map-get? asset-ownership asset-id))
)

;; Marketplace control
(define-public (toggle-marketplace (active bool))
    (begin
        (asserts! (is-marketplace-owner) ERR-NOT-AUTHORIZED)
        (var-set marketplace-active active)
        (ok true)
    )
)

;; Asset registration
(define-public (register-asset (asset-id (string-ascii 64)) (owner principal))
    (begin
        (asserts! (is-marketplace-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? asset-ownership asset-id)) ERR-ALREADY-LISTED)
        
        (map-set asset-ownership asset-id owner)
        (ok true)
    )
)

;; Balance management
(define-public (deposit-funds (amount uint))
    (begin
        (asserts! (var-get marketplace-active) ERR-MARKETPLACE-CLOSED)
        (asserts! (> amount u0) ERR-INVALID-PRICE)
        
        (map-set user-balances tx-sender 
            (+ (default-to u0 (map-get? user-balances tx-sender)) amount))
        (ok true)
    )
)

(define-public (withdraw-funds (amount uint))
    (let ((current-balance (default-to u0 (map-get? user-balances tx-sender))))
        (asserts! (>= current-balance amount) ERR-INSUFFICIENT-FUNDS)
        
        (map-set user-balances tx-sender (- current-balance amount))
        (ok true)
    )
)

;; Create asset listing
(define-public (create-listing 
    (asset-id (string-ascii 64)) 
    (price uint) 
    (royalty-recipient (optional principal)) 
    (royalty-percentage uint)
    (category (string-ascii 32)))
    (begin
        (asserts! (var-get marketplace-active) ERR-MARKETPLACE-CLOSED)
        (asserts! (owns-asset asset-id) ERR-NOT-AUTHORIZED)
        (asserts! (>= price MIN-PRICE) ERR-INVALID-PRICE)
        (asserts! (<= royalty-percentage MAX-ROYALTY) ERR-ROYALTY-TOO-HIGH)
        
        (let (
            (listing-id (var-get listing-counter))
            (current-block block-height)
            (expiry-block (+ current-block LISTING-DURATION))
        )
            (map-set asset-listings listing-id {
                asset-id: asset-id,
                seller: tx-sender,
                price: price,
                listed-at: current-block,
                expires-at: expiry-block,
                sold: false,
                cancelled: false,
                buyer: none,
                royalty-recipient: royalty-recipient,
                royalty-percentage: royalty-percentage,
                category: category
            })
            (var-set listing-counter (+ listing-id u1))
            (ok listing-id)
        )
    )
)

;; Purchase asset with escrow
(define-public (purchase-asset (listing-id uint))
    (let (
        (listing (unwrap! (map-get? asset-listings listing-id) ERR-LISTING-NOT-FOUND))
        (buyer-balance (default-to u0 (map-get? user-balances tx-sender)))
    )
        (asserts! (var-get marketplace-active) ERR-MARKETPLACE-CLOSED)
        (asserts! (not (is-eq tx-sender (get seller listing))) ERR-SELF-PURCHASE)
        (asserts! (<= block-height (get expires-at listing)) ERR-LISTING-EXPIRED)
        (asserts! (not (get sold listing)) ERR-ALREADY-SOLD)
        (asserts! (not (get cancelled listing)) ERR-LISTING-EXPIRED)
        (asserts! (>= buyer-balance (get price listing)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Deduct from buyer balance and place in escrow
        (map-set user-balances tx-sender (- buyer-balance (get price listing)))
        (map-set escrow-holds {listing-id: listing-id, buyer: tx-sender}
            {amount: (get price listing), release-at: (+ block-height ESCROW-PERIOD)})
        
        ;; Update listing
        (map-set asset-listings listing-id 
            (merge listing {sold: true, buyer: (some tx-sender)}))
        
        (ok true)
    )
)

;; Complete transaction and distribute funds
(define-public (complete-purchase (listing-id uint))
    (let (
        (listing (unwrap! (map-get? asset-listings listing-id) ERR-LISTING-NOT-FOUND))
        (escrow (unwrap! (map-get? escrow-holds {listing-id: listing-id, buyer: tx-sender}) ERR-NOT-AUTHORIZED))
        (seller (get seller listing))
        (sale-price (get amount escrow))
        (marketplace-fee-amount (/ (* sale-price MARKETPLACE-FEE) u10000))
        (royalty-amount (/ (* sale-price (get royalty-percentage listing)) u10000))
        (seller-amount (- sale-price (+ marketplace-fee-amount royalty-amount)))
    )
        (asserts! (>= block-height (get release-at escrow)) ERR-LISTING-EXPIRED)
        (asserts! (get sold listing) ERR-ALREADY-SOLD)
        
        ;; Transfer asset ownership
        (map-set asset-ownership (get asset-id listing) tx-sender)
        
        ;; Distribute funds
        (map-set user-balances seller 
            (+ (default-to u0 (map-get? user-balances seller)) seller-amount))
        
        ;; Pay royalties if applicable
        (match (get royalty-recipient listing)
            recipient (map-set user-balances recipient 
                (+ (default-to u0 (map-get? user-balances recipient)) royalty-amount))
            true)
        
        ;; Add to platform treasury
        (var-set platform-treasury (+ (var-get platform-treasury) marketplace-fee-amount))
        
        ;; Update volume
        (var-set total-volume (+ (var-get total-volume) sale-price))
        
        ;; Clean up escrow
        (map-delete escrow-holds {listing-id: listing-id, buyer: tx-sender})
        
        (ok true)
    )
)

;; Cancel listing
(define-public (cancel-listing (listing-id uint))
    (let (
        (listing (unwrap! (map-get? asset-listings listing-id) ERR-LISTING-NOT-FOUND))
    )
        (asserts! (or (is-marketplace-owner) (is-eq tx-sender (get seller listing))) ERR-NOT-AUTHORIZED)
        (asserts! (not (get sold listing)) ERR-ALREADY-SOLD)
        (asserts! (<= block-height (get expires-at listing)) ERR-LISTING-EXPIRED)
        
        (map-set asset-listings listing-id (merge listing {cancelled: true}))
        (ok true)
    )
)

;; Rate user after transaction
(define-public (rate-user (user principal) (rating uint))
    (begin
        (asserts! (<= rating u5) ERR-INVALID-PRICE)
        (asserts! (>= rating u1) ERR-INVALID-PRICE)
        
        (let (
            (current-rating (default-to {total-rating: u0, rating-count: u0} 
                (map-get? user-ratings user)))
        )
            (map-set user-ratings user {
                total-rating: (+ (get total-rating current-rating) rating),
                rating-count: (+ (get rating-count current-rating) u1)
            })
            (ok true)
        )
    )
)

;; Withdraw platform fees (owner only)
(define-public (withdraw-treasury (amount uint))
    (begin
        (asserts! (is-marketplace-owner) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get platform-treasury)) ERR-INSUFFICIENT-FUNDS)
        
        (var-set platform-treasury (- (var-get platform-treasury) amount))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-listing (listing-id uint))
    (map-get? asset-listings listing-id)
)

(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-asset-owner (asset-id (string-ascii 64)))
    (map-get? asset-ownership asset-id)
)

(define-read-only (get-user-rating (user principal))
    (let ((rating-data (default-to {total-rating: u0, rating-count: u0} 
            (map-get? user-ratings user))))
        (if (> (get rating-count rating-data) u0)
            (some (/ (get total-rating rating-data) (get rating-count rating-data)))
            none)
    )
)

(define-read-only (get-marketplace-stats)
    {
        total-listings: (var-get listing-counter),
        total-volume: (var-get total-volume),
        platform-treasury: (var-get platform-treasury),
        marketplace-active: (var-get marketplace-active)
    }
)

(define-read-only (get-escrow-info (listing-id uint) (buyer principal))
    (map-get? escrow-holds {listing-id: listing-id, buyer: buyer})
)