pragma solidity ^0.4.25;


contract Chat{
    event messageSentEvent(string message, address Sender, uint256 timestamp);

	function sendMessage(string message) public{
	    require(bytes(message).length > 0);
	    
	    
	    
	    emit messageSentEvent(message, msg.sender, now);
	}
}
