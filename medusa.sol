pragma solidity >= 0.4.25;

contract Medusa {

    event NewFileAdded(uint Id, string name, uint cost, string desc);

    address payable public Admin;

    constructor() public{
        Admin = msg.sender;
        Clearance[Admin] = 99999;
    }

    modifier AdminOnly()
    {
        require(Admin == msg.sender, "Not Admin");
        _;
    }
    uint public fileCount = 0;
    uint public userCount = 1;

    struct File{
        string fileName;
        string IPFSLoc;
        address Owner;
        uint Cost;
        string Desc;
        uint Clearance;
    }

    File[] public files;
    address payable[] public users;
    
    mapping(address=>uint) public Payments;
    mapping(address => uint) Clearance;
    mapping(uint => File) AccessFile;

    function _createFile(string memory _fileName, string memory _IPFSLoc, uint _Cost, string memory _Desc, uint _Clearance) public AdminOnly returns(uint){
        uint id = files.push(File(_fileName,_IPFSLoc,msg.sender,_Cost,_Desc,_Clearance));
        fileCount++;
        return id;
        
        emit NewFileAdded(id, _fileName, _Cost, _Desc);
    }

    function () external payable {
        require(msg.value >= 1 wei,"don't be a pauper here");
        require(Admin != msg.sender,"admin above all");
        if(Clearance[msg.sender] == 0){
            users.push(msg.sender);
            Clearance[msg.sender] = 1;
            userCount++;
            Payments[msg.sender]=0;
        }
    }

    function paySum() public payable {
        
        require(msg.value > 5);
        Payments[msg.sender] += msg.value;
        Clearance[msg.sender] = Payments[msg.sender]/5;
    }

    function requestFile(uint Id) public view returns(string memory){
        require(Clearance[msg.sender] >= files[Id].Clearance, "Upgrade Clearance");
        return files[Id].IPFSLoc;
    }

    function payAdmin() public AdminOnly{
        Admin.transfer(address(this).balance);
    }
}
