# Project3

**TODO: Add description**

## Installation

Group Members:
Saptarshi Chakraborty, UFID - 8857-1418
Vagisha Tyagi , UFID - 0428-9808

What is working - 

The algorithm works with 100% convergence.
We have used 128 bits id as the node id. The id is represented in hexa-decimal format.
It detects the network loop condition and if it forms a loop, then another intermediate node is selected so that no island like structure is not formed.

Largest Network -

10000 Nodes with 10 requests for each node - >  Average hop 3.04


Assumptions and Notes - 
The algorithm waits for 10 seconds to ensure all the nodes have receievd the messages. We decided this value based on our rxperimental results that on average it does not exceed 10 seconds to complete the routing.



