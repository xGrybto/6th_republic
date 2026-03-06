# 6th Republic

This is my first blockchain project, which will help me to improve my knowledges by applying all kind of stuff that I will learn during my journey.

A big part of this journey will be to follow the Cyfrin courses, which I'm sure will be very helpful for me.

## Introduction

Nowadays, some countries are defined as democracies.

Democracy is a political system in which power belongs to the people, who exercise it directly or through elected representatives.
It is based on fundamental principles such as citizen participation, freedom of expression, equality before the law, and respect for fundamental rights.

To put it simply, there are two democratic models: representative democracy (the most common) and direct and participatory democracy. Participatory democracy allows the people to exercise power directly, as in a referendum (an exceptional event).
Maintaining a model like this remains complicated because there are many constraints:
- the need to vote regularly (travel, availability, etc.)
- weakening of the political culture of the people, who have little responsibility and little knowledge of the issues

The 6th Republic is trying to bring a new way of voting, through the concepts of blockchain, smart contracts and decentralized autonomous organization (DAO). 
This technologies offer a big opportunity to get closer to a participatory democracy, which I'm sure is way better than old/representative democracy.

Here is how I see it could works for now :
- A citizen:
    - has one voting power
    - has one signature power
    - can do a proposal
    - can delegate his vote to another citizen, which can cumulate voting power
    - may decide to delegate his vote to several citizens depending on the subject of the proposal (economy, ecology, health, education, etc.).
    - can revoke at any time his delegation(s) for future proposition
    - cannot delegate a signature
      
- A proposal needs to reach a certain number of signatures before it can be put to a vote

- A vote has 3 answers possible : YES, NO, (VETO)
- A proposal is voted when the majority is voted.

Topics to discuss about :
- How trust a citizen numerical decision (vote, delegation, signature) ? Can we trust current KYC model ?
  Idea #1 : Each citizen receive an SBT ID card in their wallet (could be specific wallet for election purpose) when they create the real one, delivered by the government. Each decision need to be done with a biometric verification. 
- Is it fair and not risky to give to each citizen a voting power of one ? If not, how can we fairly adjust voting power to the right persons (which is hard to define)/the experts in the dedicated domain of the proposal, ...
- How can we deal with the privacy (of voting, delegating, ...) => ZKPs ?

## Current system - Draft n°4

### Key concepts
- "Soulbound Token" (SBT) for uniq passport
- EnumerableMap from OpenZeppelin for handling votes (https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableMap)
- Enumeration for vote choice (NULL, YES, NO) : first value is NULL. The enum structure is simply an array of uint. This way, the default value in the mapping "votes" is NULL if a citizen didn't vote.
- Add an orchestrator to manage the state between passport and proposal contracts
- Introduce pausable functionnality in passport and proposal contracts

### Passport functionnalities
- Mint of a passport
- Delegation logic (delegate, revoke delegation)
- Enable/Disable delegation mode. Default : disable

### Proposal functionnalities
- Create a proposal
    - Any citizen with a passport can open a proposal
    - The proposal is in preparation for 1 day. During this time, you can manage your delegate status and your delegation.
    - Only one proposal at a time: a new proposal can't be created as long as the one before is not ended.
- Start the vote of the proposal : the vote is open for 3 days. During this period, you can't manage delegation functionnalities anymore.
- Vote for a proposal : YES, NO
- End a proposal with timeout duration : need to call "vote" function when the period of vote is over.
    - Any participant/passport holder can close the vote, even if they already voted
- The count of votes is done directly when it ends, and emit a "VoteResult" event (the outcome of the vote is not decided on-chain as in previous draft).
