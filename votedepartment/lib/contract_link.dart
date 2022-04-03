import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

class ContractLinking extends ChangeNotifier {
  final String _rpcUrl = "http://127.0.0.1:7545";
  final String _wsUrl = "ws://127.0.0.1:7545/";
  final String _privateKey =
      "47ef1b923039012a89b1b8172fa74c4d2f416d74cc7714ca9c924bee64cadf36";
  late EthereumAddress owner;

  late Web3Client _client;
  late String _abiCode;

  late Credentials _credentials;

  late EthereumAddress _contractAddress;

  late DeployedContract _contract;
  late ContractFunction _addCandidate;
  late ContractFunction _voteFunc;
  late ContractFunction _totalVotes;
  late ContractFunction _numOfCandidates;
  late ContractFunction _numOfVoters;
  late ContractFunction _getCandidate;
  late ContractFunction _startVoting;
  late ContractFunction _stopVoting;
  late ContractFunction _getState;
  late ContractFunction _addCat;
  late ContractFunction _catCount;
  late ContractFunction _returnCats;

  late ContractEvent _returnCandidateID;
  late ContractEvent _error;
  late ContractEvent _isCreated;
  late ContractEvent _isVoting;

  bool isLoading = false;

  // temp
  var txt = TextEditingController();

  ContractLinking() {
    inititalSetup();
  }

  inititalSetup() async {
    _client = Web3Client(_rpcUrl, Client(), socketConnector: () {
      return WebSocketChannel.connect(Uri.parse(_wsUrl)).cast<String>();
    });
    await getAbi();
    await getCredentials();
    await getDeployedContract();

    //await voting();
  }

  Future<void> getAbi() async {
    String abiStringFile =
        await rootBundle.loadString("src/artifacts/Ballot.json");
    var jsonFile = jsonDecode(abiStringFile);
    _abiCode = jsonEncode(jsonFile["abi"]);
    _contractAddress =
        EthereumAddress.fromHex(jsonFile["networks"]["5777"]["address"]);
  }

  Future<void> getCredentials() async {
    _credentials = EthPrivateKey.fromHex(_privateKey);
    owner = await _credentials.extractAddress();
  }

  Future<void> getDeployedContract() async {
    _contract = DeployedContract(
        ContractAbi.fromJson(_abiCode, "Ballot"), _contractAddress);

    _addCandidate = _contract.function("addCandidate");
    _voteFunc = _contract.function("vote");
    _totalVotes = _contract.function("totalVotes");
    _numOfCandidates = _contract.function("getNumOfCandidates");
    _numOfVoters = _contract.function("getNumOfVoters");
    _getCandidate = _contract.function("getCandidate");
    _startVoting = _contract.function("startVoting");
    _stopVoting = _contract.function("stopVoting");
    _getState = _contract.function("currentState");
    _addCat = _contract.function("addCats");
    _catCount = _contract.function("returnCatCount");
    _returnCats = _contract.function("returnCats");

    // events
    _returnCandidateID = _contract.event("AddedCandidate");
    _error = _contract.event("Error");
    _isCreated = _contract.event("isCreated");
    _isVoting = _contract.event("isVoting");
  }

  Future<void> addCat(String name) async {
    isLoading = true;
    notifyListeners();
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
          from: owner,
          contract: _contract,
          function: _addCat,
          parameters: [name]),
    );
    print("Voter Registered $name");
    isLoading = false;
    notifyListeners();
  }

  // dep.app
  Future<void> registerVoter(String name, String party) async {
    isLoading = true;
    notifyListeners();
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
          from: owner,
          contract: _contract,
          function: _addCandidate,
          parameters: [name, party]),
    );
    getNumOfCandidates();
    print("Voter Registered $name");
    isLoading = false;
  }

  // Start Voting
  Future<void> startVoting() async {
    isLoading = true;
    notifyListeners();
    await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
            contract: _contract, function: _startVoting, parameters: []));
    await votingState();
    isLoading = false;
  }

  // End Voting
  Future<void> stopVoting() async {
    isLoading = true;
    notifyListeners();
    await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
            contract: _contract, function: _stopVoting, parameters: []));
    isLoading = false;
    notifyListeners();
    //await votingState();
  }

  // voting
  vote(String uid, BigInt candidateID) async {
    isLoading = true;
    notifyListeners();
    await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
            contract: _contract,
            function: _voteFunc,
            parameters: [(uid), candidateID]));
    //getChairperson();
  }

  Future<void> getNumOfCandidates() async {
    notifyListeners();
    await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
            contract: _contract, function: _numOfCandidates, parameters: []));
  }

  // dep.app
  getNumOfVoters() async {
    notifyListeners();
    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
          contract: _contract, function: _numOfVoters, parameters: []),
    );
  }

  getCandidate(BigInt candidateID) async {
    notifyListeners();

    var candidates = await _client.call(
        contract: _contract, function: _getCandidate, params: [candidateID]);
    return candidates;
  }

  // State Getter
  Future<BigInt> getState() async {
    List state = (await _client
        .call(contract: _contract, function: _getState, params: []));
    notifyListeners();
    return state.first;
  }

  // depp and public
  totalVotes(BigInt candidateID) async {
    notifyListeners();

    var tvotes = await _client.call(
        contract: _contract, function: _totalVotes, params: [candidateID]);
    return "$tvotes";
  }

  // depp and public
  winner() async {
    var numOfVotes = await _client
        .call(contract: _contract, function: _totalVotes, params: []);
    return numOfVotes;
  }

  // Event Listeners

  Future<BigInt> returnCandidateID() async {
    notifyListeners();
    final event = await _client
        .events(FilterOptions.events(
            contract: _contract, event: _returnCandidateID))
        .first;
    final decoded =
        _returnCandidateID.decodeResults(event.topics!, event.data ?? '');
    final id = decoded[0] ?? '' as BigInt;
    return id;
  }

  Future<String> error() async {
    notifyListeners();
    final event = await _client
        .events(FilterOptions.events(contract: _contract, event: _error))
        .first;
    final decoded = _error.decodeResults(event.topics!, event.data ?? '');
    final errorcode = decoded[0] ?? '';
    return errorcode;
  }

  Future<bool> createdState() async {
    notifyListeners();
    final event = await _client
        .events(FilterOptions.events(contract: _contract, event: _isCreated))
        .first;
    final decoded = _isCreated.decodeResults(event.topics!, event.data ?? '');
    final state = decoded[0] ?? '' as bool;
    return state;
  }

  Future<bool> votingState() async {
    final event = await _client
        .events(FilterOptions.events(contract: _contract, event: _isVoting))
        .first;
    final decoded = _isVoting.decodeResults(event.topics!, event.data ?? '');
    final state = decoded[0] ?? '' as bool;
    notifyListeners();
    return state;
  }

  Future<BigInt> catCount() async {
    var numOfVotes = await _client
        .call(contract: _contract, function: _catCount, params: []);
    return numOfVotes.first;
  }

  Future<List> returnCats() async {
    // rec a bigInt
    BigInt count = await catCount();
    // Parsing 2 int
    int count2 = count.toInt();
    var list = <List>[];

    for (int i = 0; i < count2; i++) {
      var cats = await _client.call(
          contract: _contract, function: _returnCats, params: [BigInt.from(i)]);
      list.add(cats);
    }
    notifyListeners();
    return list;
  }
}
