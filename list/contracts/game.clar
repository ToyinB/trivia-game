;; Trivia Game Smart Contract with Enhanced Security

;; Constants for Errors
(define-constant ERR_INVALID_QUESTION_ID u1)
(define-constant ERR_QUESTION_ALREADY_EXISTS u2)
(define-constant ERR_UNAUTHORIZED u3)
(define-constant ERR_INVALID_INPUT u4)
(define-constant ERR_GAME_NOT_ACTIVE u5)
(define-constant ERR_ALREADY_ANSWERED u6)
(define-constant ERR_INCORRECT_ANSWER u7)

;; Input Validation Functions
(define-private (is-valid-question-text (text (string-ascii 500)))
  (and 
    (> (len text) u0)
    (<= (len text) u500)
  )
)

(define-private (is-valid-answer-text (text (string-ascii 100)))
  (and 
    (> (len text) u0)
    (<= (len text) u100)
  )
)

(define-private (is-valid-reward (amount uint))
  (> amount u0)
)

(define-private (is-valid-question-id (id uint))
  (and 
    (> id u0)
    (<= id (var-get total-questions))
  )
)

;; Storage - Questions
(define-map questions 
  { id: uint }
  {
    question: (string-ascii 500),
    correct-answer: (string-ascii 100),
    reward: uint,
    is-active: bool
  }
)

;; Storage - Player Answers
(define-map player-answers 
  { player: principal, question-id: uint }
  { answered: bool }
)

;; Storage - Game Configuration
(define-data-var contract-owner principal tx-sender)
(define-data-var total-questions uint u0)
(define-data-var game-active bool true)

;; Modifiers
(define-read-only (is-contract-owner (user principal))
  (is-eq user (var-get contract-owner))
)

;; Admin Functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    ;; Validate input
    (asserts! (not (is-eq new-owner tx-sender)) (err ERR_INVALID_INPUT))
    
    ;; Verify current owner
    (asserts! (is-contract-owner tx-sender) (err ERR_UNAUTHORIZED))
    
    ;; Set new owner
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (toggle-game-status)
  (begin
    ;; Verify contract owner
    (asserts! (is-contract-owner tx-sender) (err ERR_UNAUTHORIZED))
    
    ;; Toggle game status
    (var-set game-active (not (var-get game-active)))
    (ok (var-get game-active))
  )
)

;; Question Management
(define-public (add-question 
  (question (string-ascii 500)) 
  (correct-answer (string-ascii 100))
  (reward uint)
)
  (begin
    ;; Validate inputs
    (asserts! (is-valid-question-text question) (err ERR_INVALID_INPUT))
    (asserts! (is-valid-answer-text correct-answer) (err ERR_INVALID_INPUT))
    (asserts! (is-valid-reward reward) (err ERR_INVALID_INPUT))
    
    ;; Verify contract owner
    (asserts! (is-contract-owner tx-sender) (err ERR_UNAUTHORIZED))
    
    ;; Ensure game is active when adding questions
    (asserts! (var-get game-active) (err ERR_GAME_NOT_ACTIVE))
    
    ;; Calculate new question ID
    (let 
      ((new-question-id (+ (var-get total-questions) u1)))
      
      ;; Check if question already exists
      (asserts! 
        (is-none (map-get? questions { id: new-question-id })) 
        (err ERR_QUESTION_ALREADY_EXISTS)
      )
      
      ;; Add question to map
      (map-set questions 
        { id: new-question-id }
        {
          question: question,
          correct-answer: correct-answer,
          reward: reward,
          is-active: true
        }
      )
      
      ;; Update total questions
      (var-set total-questions new-question-id)
      
      ;; Return new question ID
      (ok new-question-id)
    )
  )
)

;; Answer Submission
(define-public (submit-answer 
  (question-id uint)
  (submitted-answer (string-ascii 100))
)
  (begin
    ;; Validate inputs
    (asserts! (is-valid-question-id question-id) (err ERR_INVALID_QUESTION_ID))
    (asserts! (is-valid-answer-text submitted-answer) (err ERR_INVALID_INPUT))
    
    ;; Validate game is active
    (asserts! (var-get game-active) (err ERR_GAME_NOT_ACTIVE))
    
    ;; Validate question exists
    (match (map-get? questions { id: question-id })
      question-details
      ;; Check if player has already answered this question
      (match (map-get? player-answers { player: tx-sender, question-id: question-id })
        existing-answer
        (err ERR_ALREADY_ANSWERED)
        (if (is-eq (get correct-answer question-details) submitted-answer)
            (begin
              ;; Mark answer as submitted
              (map-set player-answers 
                { player: tx-sender, question-id: question-id }
                { answered: true }
              )
              
              ;; Transfer reward
              (try! (stx-transfer? 
                (get reward question-details) 
                tx-sender 
                (var-get contract-owner)
              ))
              (ok true)
            )
            (err ERR_INCORRECT_ANSWER)
        )
      )
      (err ERR_INVALID_QUESTION_ID)
    )
  )
)

;; Read Functions
(define-read-only (get-question-details (question-id uint))
  (map-get? questions { id: question-id })
)

(define-read-only (get-total-questions)
  (var-get total-questions)
)

(define-read-only (is-question-answered (player principal) (question-id uint))
  (map-get? player-answers { player: player, question-id: question-id })
)

;; Utility Functions
(define-read-only (get-game-status)
  (var-get game-active)
)