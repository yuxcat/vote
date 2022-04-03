// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;
// written for Solidity version 0.4.18 and above that doesnt break functionality

contract Ballot {
    // Events
    event AddedCandidate(uint candidateID);
    event AddedEntry(string rid, uint id);
    event Error(string error);

    // States Events
    event isCreated(bool cState);
    event isVoting(bool cState);

    event AddedCat(uint id, string name);

    // describes a Voter, which has an id and the ID of the candidate they voted for
    address owner;

    constructor ()  {
        owner = msg.sender;
        state = State.Created;
        emit isCreated(true);
        emit isVoting(false);
    }

    // modifiers
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier inState(State _state) {
        require((state == _state));
        _;
    }
    struct Voter {
        uint candidateIDVote;
        uint catid;
    }


    // describes a Candidate
    struct Candidate {
        string name;
        string party;
        // "bool doesExist" is to check if this Struct exists
        // This is so we can keep track of the candidates 
        bool doesExist;
    }

    // Categories
    struct Cats {
        string name;
        uint count;
    }

    // structfor vals
    struct Anon {
        bool voted;
        uint id;
    }


    // These state variables are used keep track of the number of Candidates/Voters 
    // and used to as a way to index them     
    uint numCandidates; // declares a state variable - number Of Candidates
    uint numVoters;
    uint numCats;


    // Think of these as a hash table, with the key as a uint and value of 
    // the struct Candidate/Voter. These mappings will be used in the majority
    // of our transactions/calls
    // These mappings will hold all the candidates and Voters respectively
    mapping(uint => Candidate) candidates;
    mapping(uint => Voter) voters;
    mapping(string => Anon) anony;
    mapping(uint => Cats) cats;

    // States
    enum State {Created, Voting, Ended}
    State public state;


    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *  These functions perform transactions, editing the mappings *
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    // 4da Validations / entry of category id
    function entry(string memory rid, uint id) onlyOwner public
    inState(State.Created)
    {

        anony[rid] = Anon(false, id);
        emit AddedEntry(rid, id);
    }

    // state init for voting
    function startVoting() onlyOwner public
    inState(State.Created)
    {
        state = State.Voting;
        emit isVoting(true);
    }

    // stop voting
    function stopVoting() onlyOwner public
    inState(State.Voting)
    {
        state = State.Ended;
        emit isVoting(false);
    }


    function addCandidate(string memory name, string memory party) onlyOwner public
    inState(State.Created)
    {
        // candidateID is the return variable
        uint candidateID = numCandidates++;
        // Create new Candidate Struct with name and saves it to storage.
        candidates[candidateID] = Candidate(name, party, true);
        emit AddedCandidate(candidateID);
    }

    function addCats(string memory name)
    onlyOwner
    public
    inState(State.Created)
    {
        uint id = numCats++;
        cats[id] = Cats(name, 0);
        emit AddedCat(id, name);

    }

    function vote(uint candidateID, string memory rid) public
    inState(State.Voting)
    {
        // checks if the struct exists for that candidate
        if (candidates[candidateID].doesExist == true && anony[rid].voted == false) {
            uint voterID = numVoters++;
            uint id = anony[rid].id;

            //voterID is the return variable
            voters[voterID] = Voter(candidateID, id);
            // increment cats
            cats[id].count += 1;

            // setter voter voted
            anony[rid].voted = true;
        }
        else {
            emit Error("voting failed : Invalid Candidate / Voter");
        }
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * 
     *  Getter Functions *
     * * * * * * * * * * * * * * * * * * * * * * * * * */


    // finds the total amount of votes for a specific candidate by looping
    // through voters 
    function totalVotes(uint candidateID) view public returns (uint) {
        uint numOfVotes = 0;
        // we will return this
        for (uint i = 0; i < numVoters; i++) {
            // if the voter votes for this specific candidate, we increment the number
            if (voters[i].candidateIDVote == candidateID) {
                numOfVotes++;
            }
        }
        return numOfVotes;
    }

    function advancedVotes(uint candidateid, uint inputcat) view public returns (uint) {
        uint numVotes = 0;
        for (uint i = 0; i < numVoters; i++) {
            if (voters[i].candidateIDVote == candidateid && voters[i].catid == inputcat) {
                numVotes++;
            }
        }
        return numVotes;

    }

    // voters by cat
    function specificVotes(uint inputcat) view public returns (uint) {
        uint numVotes = 0;
        for (uint i = 0; i < numVoters; i++) {
            if (voters[i].catid == inputcat) {
                numVotes++;
            }
        }
        return numVotes;

    }

    // Return Cat Details
    function returnCats(uint id) public view returns (uint, string memory, uint) {
        return (id, cats[id].name, cats[id].count);
    }

    // return cats count
    function returnCatCount()
    public
    view
    returns
    (uint)
    {
        return numCats;

    }

    function getNumOfCandidates() public view returns (uint) {
        return numCandidates;
    }

    function getNumOfVoters() public view returns (uint) {
        return numVoters;
    }
    // returns candidate information, including its ID, name, and party
    function getCandidate(uint candidateID) public view returns (uint, string memory, string memory) {
        return (candidateID, candidates[candidateID].name, candidates[candidateID].party);
    }

    function returnMappingValue(string memory rid) public view returns (bool) {
        return (anony[rid].voted);
    }

    function currentState() public view returns (State) {
        return state;
    }
}