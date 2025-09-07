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

The 6th Republic is trying to bring a new way of voting, through the concept of blockchain, smart contracts and decentralized autonomous organization (DAO). 
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
      
- A proposal can be signed by citizens
- A proposal is turned into a bill after X signatures

- A bill has 3 answers possible : YES, NO, (VETO)
- A bill is voted when the majority is voted.

Topics to discuss about :
- How trust a citizen numerical decision (vote, delegation, signature) ? Can we trust current KYC model ?
  Idea #1 : Each citizen receive an SBT ID card in their wallet (could be specific wallet for election purpose) when they create the real one, delivered by the government. Each decision need to be done with a biometric verification. 
- Is it fair and not risky to give to each citizen a voting power of one ? If not, how can we fairly adjust voting power to the right persons (which is hard to define)/the experts in the dedicated domain of the proposal, ...
- How can we deal with the privacy (of voting, delegating, ...) => ZKPs ?


## First draft 
### 6RPassport
The following principles must be implemented :
- Eligibility of voting for citizen who has a 6RPassport SBT delivered by designated entity (eg: administration)
- Voting power of one for each registered citizen
- Delegate vote to one person
- Revoke vote to one person
- 6RPassport SBT properties :
    - Non transferable (by definition "Soul Bound Token")
    - Mintable by designated entity (aka. Owner)

## Second draft
### 6RPassport
- 6RPassport SBT properties :
    - Non transferable (by definition "Soul Bound Token")
    - Mintable by designated entity (aka. Owner)
    - ***Burnable when ID card expires***
- Eligibility of voting for citizen who has a 6RPassport SBT delivered by designated entity (eg: administration)
- Voting power of one for each registered citizen
- Delegate vote to one person
- Revoke vote to one person
- ***Handle expired/non existent 6RPassport (delegation, ...)***

## Third draft
### 6RPassport
- 6RPassport SBT properties :
    - Non transferable (by definition "Soul Bound Token")
    - Mintable by designated entity (aka. Owner)
    - Burnable when ID card expires
- Eligibility of voting for citizen who has a 6RPassport SBT delivered by designated entity (eg: administration)
- Voting power of one for each registered citizen
- Delegate full vote to one person, ***or to one person for each voting category***
- Revoke vote to one person, ***or to one person for each voting category***
- Handle expired/non existent 6RPassport (delegation, ...)

## Fourth draft
### 6RPassport
- 6RPassport SBT properties :
    - Non transferable (by definition "Soul Bound Token")
    - Mintable by designated entity (aka. Owner)
    - Burnable when ID card expires
- Eligibility of voting for citizen who has a 6RPassport SBT delivered by designated entity (eg: administration)
- Voting power of one for each registered citizen
- Delegate full vote to one person, or to one person for each voting category
- Revoke vote to one person, or to one person for each voting category
- Handle expired/non existent 6RPassport (delegation, ...)
### 6RProposal
- ***Create a proposal if citizen owns a 6RPassport***
- ***Signature of a proposal***
- ***Proposal turn into a bill after thresold of signatures reached.***

## After 
- Vote for the bill
- ...
