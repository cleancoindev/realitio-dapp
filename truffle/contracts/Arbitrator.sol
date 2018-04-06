pragma solidity ^0.4.18;

import './Owned.sol';
import './RealityCheck.sol';

contract Arbitrator is Owned {

    uint256 dispute_fee;
    mapping(bytes32 => uint256) custom_dispute_fees;

    event LogRequestArbitration(
        bytes32 indexed question_id,
        uint256 fee_paid,
        address requester,
        uint256 remaining
    );

    event LogSetQuestionFee(
        uint256 fee
    );

    event LogSetDisputeFee(
        uint256 fee
    );

    event LogSetCustomDisputeFee(
        bytes32 indexed question_id,
        uint256 fee
    );

    /// @notice Constructor. Sets the deploying address as owner.
    function Arbitrator() 
    public {
        owner = msg.sender;
    }

    /// @notice Set the default fee
    /// @param fee The default fee amount
    function setDisputeFee(uint256 fee) 
        onlyOwner 
    public {
        dispute_fee = fee;
        LogSetDisputeFee(fee);
    }

    /// @notice Set a custom fee for this particular question
    /// @param question_id The question in question
    /// @param fee The fee amount
    function setCustomDisputeFee(bytes32 question_id, uint256 fee) 
        onlyOwner 
    public {
        custom_dispute_fees[question_id] = fee;
        LogSetCustomDisputeFee(question_id, fee);
    }

    /// @notice Return the dispute fee for the specified question. 0 indicates that we won't arbitrate it.
    /// @param question_id The question in question
    /// @dev Uses a general default, but can be over-ridden on a question-by-question basis.
    function getDisputeFee(bytes32 question_id) 
    public constant returns (uint256) {
        return (custom_dispute_fees[question_id] > 0) ? custom_dispute_fees[question_id] : dispute_fee;
    }

    /// @notice Set a fee for asking a question with us as the arbitrator
    /// @param realitycheck The RealityCheck contract address
    /// @param fee The fee amount
    /// @dev Default is no fee. Unlike the dispute fee, 0 is an acceptable setting.
    /// You could set an impossibly high fee if you want to prevent us being used as arbitrator unless we submit the question.
    /// (Submitting the question ourselves is not implemented here.)
    /// This fee can be used as a revenue source, an anti-spam measure, or both.
    function setQuestionFee(address realitycheck, uint256 fee) 
        onlyOwner 
    public {
        RealityCheck(realitycheck).setQuestionFee(fee);
        LogSetQuestionFee(fee);
    }

    /// @notice Submit the arbitrator's answer to a question.
    /// @param realitycheck The RealityCheck contract address
    /// @param question_id The question in question
    /// @param answer The answer
    /// @param answerer The answerer. If arbitration changed the answer, it should be the payer. If not, the old answerer.
    function submitAnswerByArbitrator(address realitycheck, bytes32 question_id, bytes32 answer, address answerer) 
        onlyOwner 
    public {
        RealityCheck(realitycheck).submitAnswerByArbitrator(question_id, answer, answerer);
    }

    /// @notice Request arbitration, freezing the question until we send submitAnswerByArbitrator
    /// @dev The bounty must be paid in full. To split it among multiple people, use another contract
    /// Will trigger an error if the notification fails, eg because the question has already been finalized
    /// @param realitycheck The RealityCheck contract address
    /// @param question_id The question in question
    function requestArbitration(address realitycheck, bytes32 question_id) 
    external payable {

        uint256 arbitration_fee = getDisputeFee(question_id);
        require(arbitration_fee > 0);

        require(msg.value >= arbitration_fee);

        RealityCheck(realitycheck).notifyOfArbitrationRequest(question_id, msg.sender);
        LogRequestArbitration(question_id, msg.value, msg.sender, 0);

    }

    /// @notice Withdraw any accumulated fees to the specified address
    /// @param addr The address to which the balance should be sent
    function withdraw(address addr) 
        onlyOwner 
    public {
        addr.transfer(this.balance); 
    }

    function() 
    public payable {
    }

    /// @notice Withdraw any accumulated question fees from the specified address into this contract
    /// @param realitycheck The address of the Reality Check contract containing the fees
    /// @dev Funds can then be liberated from this contract with our withdraw() function
    function callWithdraw(address realitycheck) 
        onlyOwner 
    public {
        RealityCheck(realitycheck).withdraw(); 
    }

}
