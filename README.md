## 6th Republic

This is my first blockchain project, which will help me to improve my knowledges by applying all kind of stuff that I will learn during my journey.

A big part of this journey will be to follow the Cyfrin courses, which I'm sure will be very helpful for me.


The 6th Republic is an idea of renew the France republic, and more accurately the democracy that we have nowadays.

Through the concept of blockchain, and decentralized autonomous organization (DAO), there is a big potential of recreate the democracy, I can even say to be very close of a perfect democracy, where the power is held by the citizens, for the citizens.

Here is how I see it could works for now :
- Every citizen has one voting power
- Each citizen is allowed to vote any of the bill that the government (national assembly) propose.
- Each citizen can delegate his vote to another citizen, which can cumulate voting power.
- Each citizen can revoke at any time his delegation for future proposition.
- A proposition has 3 answers possible : YES, NO, (VETO)
- A proposition is voted when it has a majority of "YES" at the end of the voting duration.

Topics to discuss about :
- Is it fair and not risky to give to each citizen a voting power of one ? If not, how can we fairly adjust voting power to the right persons (which is hard to define)/the experts in the dedicated domain of the proposition, ...


First draft of the project :
- Create the "Proposition" smart contract with :
    - Proposition structure :
        - name
        - description
    - public vote() function
    - private deliberation() function