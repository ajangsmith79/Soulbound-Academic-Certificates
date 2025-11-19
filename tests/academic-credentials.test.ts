import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const contractName = "academic-credentials";

describe("Academic Credentials Contract Tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("allows contract owner to register institutions", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "register-institution",
      [Cl.stringAscii("Harvard University")],
      deployer
    );
    expect(result).toBeOk(Cl.uint(1));
  });

  it("prevents non-owners from registering institutions", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "register-institution",
      [Cl.stringAscii("MIT")],
      wallet1
    );
    expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
  });

  it("allows institution admin to issue certificates", () => {
    // Use Harvard University (institution ID 1) that was registered in first test
    const { result } = simnet.callPublicFn(
      contractName,
      "issue-certificate",
      [
        Cl.principal(wallet1),
        Cl.uint(1), // Harvard University
        Cl.stringAscii("Bachelor of Science"),
        Cl.stringAscii("Computer Science"),
        Cl.uint(375), // 3.75 GPA
        Cl.uint(2024),
        Cl.stringAscii("QmTestHashForCertificate123")
      ],
      deployer
    );
    expect(result).toBeOk(Cl.uint(1));
  });

  it("prevents issuing certificates with invalid GPA", () => {
    // Use Harvard University (institution ID 1) again
    const { result } = simnet.callPublicFn(
      contractName,
      "issue-certificate",
      [
        Cl.principal(wallet2),
        Cl.uint(1), // Harvard University
        Cl.stringAscii("Master of Science"),
        Cl.stringAscii("Data Science"),
        Cl.uint(450), // Invalid 4.50 GPA
        Cl.uint(2024),
        Cl.stringAscii("QmTestHashForCertificate456")
      ],
      deployer
    );
    expect(result).toBeErr(Cl.uint(105)); // ERR-INVALID-GRADE
  });

  it("allows institution admin to award achievements", () => {
    // Use Harvard University (institution ID 1) again
    const { result } = simnet.callPublicFn(
      contractName,
      "award-achievement",
      [
        Cl.principal(wallet1),
        Cl.uint(1), // Harvard University
        Cl.uint(1), // ACHIEVEMENT-HONOR-ROLL
        Cl.stringAscii("Fall 2023"),
        Cl.uint(2023),
        Cl.stringAscii("Achieved honor roll status")
      ],
      deployer
    );
    expect(result).toBeOk(Cl.uint(1));
  });

  it("prevents awarding invalid achievement types", () => {
    // Use Harvard University (institution ID 1) again
    const { result } = simnet.callPublicFn(
      contractName,
      "award-achievement",
      [
        Cl.principal(wallet2),
        Cl.uint(1), // Harvard University
        Cl.uint(10), // Invalid achievement type
        Cl.stringAscii("Spring 2024"),
        Cl.uint(2024),
        Cl.stringAscii("Invalid achievement type test")
      ],
      deployer
    );
    expect(result).toBeErr(Cl.uint(108)); // ERR-INVALID-ACHIEVEMENT-TYPE
  });

  it("correctly retrieves certificate information", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-certificate",
      [Cl.uint(1)], // Certificate ID 1 should exist from earlier test
      wallet1
    );
    expect(result).toBeSome();
  });

  it("correctly verifies certificate authenticity", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "verify-certificate",
      [Cl.uint(1)],
      wallet1
    );
    expect(result).toBeOk();
  });

  it("retrieves student certificates correctly", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-student-certificates",
      [Cl.principal(wallet1)],
      wallet1
    );
    // Should be a list, might be empty but still a list
    expect(result.type).toBe("(list 50 uint)");
  });

  it("prevents transferring soulbound certificates", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "transfer",
      [
        Cl.uint(1),
        Cl.principal(wallet1),
        Cl.principal(wallet2)
      ],
      wallet1
    );
    expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED (soulbound)
  });
});
