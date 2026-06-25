# Aether

**Group Members: Wajeeha Zahid (222201005) | Abdur Rafay (222201012)**
**Supervised by Dr. Altaf Hussain**

---

## FYP I Remarks

The following remarks were given during the FYP-I design phase evaluation. Each remark is listed below along with the corrective action taken.

| # | Remark | Response / Action Taken |
|---|--------|------------------------|
| 1 | Review architecture diagram, sequence diagram, descriptive use cases etc. | Reviewed and updated accordingly. The architecture and sequence diagrams were redrawn to match the final Hyperledger Fabric design as shown on page 76, 108, 123 and the use cases were rewritten in full descriptive form with actors, pre and post conditions, and main and alternate flows with respective numbering on page 97-115 in the main document. |
| 2 | Use case diagram must be revised. | Revised. The use case diagram now shows the three correct actors (University Admin, HEC Officer, and Student) with proper associations, and the overlapping use cases were merged for clarity. |
| 3 | Revise ERD connection. | ERD is not applicable in our proposed solution. Aether does not use a relational (SQL) database, so an ERD does not apply to this system. Data is stored on the Hyperledger Fabric ledger (CouchDB world state) and in MongoDB, a document store with GridFS for files. |
| 4 | Add AI. | Aether is a blockchain-based credential verification system. Its integrity comes from the distributed ledger, endorsement policies, and cryptographic hashing rather than from machine learning. An AI component does not fit the objectives of the project and would be an artificial addition rather than a genuine requirement, so it has intentionally been kept out of scope. |
| 5 | Correct the number of interactions. | Corrected. The number of interactions in the sequence and interaction diagrams now matches the implemented flow across the client, API gateway, Fabric gateway, peers, orderer, and MongoDB. |
| 6 | Revise sequence diagram. | Revised. The sequence diagrams for the main flows (credential issuance, burn and mint degree, and public verification) were redrawn to show the correct request and response order across the API, chaincode, and storage layers. |

---

_________________________&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;___________________________________

Project Member Signature &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Supervisor's Signature
