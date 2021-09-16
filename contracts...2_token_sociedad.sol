
// SPDX-License-Identifier: GPL-3.0
/*
    Coin de la sociedad

*/
pragma solidity >=0.7.0 <0.9.0;

contract MonedaSociedad{
    
    string public name;
    string public symbol;
    uint8 decimals;
    uint256 totalSupply;
    
    mapping (address => uint256) public balanceOf;//lleva los balances del token asociados a cada direccion
    mapping (address => mapping(address => uint256)) public allowance; // lleva el listado de direcciones y la cantidad de token que pueden manejar asociados a otras direcciones
    
    constructor(){
        name = "GranjaCoin";
        symbol = "GRAN";
        decimals = 10;
        totalSupply = 1000000000 * (uint256(10))** decimals;
        balanceOf[msg.sender] = totalSupply;
    }
    
    event Transfer(address indexed _from, address indexed _to, uint256 _val);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    
    function transfer(address _to, uint256 _value) public returns(bool status) {
        
        require(balanceOf[msg.sender] >= _value);
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    

    function approve(address _spender, uint256 _value) public returns(bool success){
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success){
        require(balanceOf[_from] >= _value);
        require(allowance [_from][msg.sender] >= _value);
        balanceOf[_from] -= _value;
        balanceOf[_to] -= _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
        
    }
    
}