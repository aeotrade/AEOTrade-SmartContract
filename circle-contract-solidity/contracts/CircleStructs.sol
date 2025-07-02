// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

library CircleStructs {
    enum ApplicationStatus {
        Pending,
        Approved,
        Rejected
    }

    enum AuditStatus {
        Pending,
        Approved,
        Rejected
    }

    // 商品类型: 1 或 2
    enum ProductType {
        Type1,
        Type2
    }

    struct Circle {
        string id; // 圈子ID
        string name; // 圈子名称
        string description; // 圈子描述
        string ownerDID; // 圈主DID
        string ownerOrgName; // 圈主组织名称
        string creatorDID; // 创建者DID
        string creatorOrgName; // 创建者组织名称
        uint256 creationTime; // 创建时间
        bool disabled; // 圈子是否禁用
    }

    struct Application {
        string applicantDID; // 申请人DID
        string orgName; // 企业名称
        string socialCreditCode; // 社会信用代码
        ApplicationStatus status; // 申请状态
    }

    struct Product {
        string id; // 商品ID
        string name; // 商品名称
        string price; // 价格
        ProductType productType; // 类型 (1 或 2)
        bool onShelf; // 上下架状态
        string ipfsHash; // IPFS地址
        AuditStatus auditStatus; // 审核状态
        string ownerDID; // 商品所有者DID
        string circleId; // 所属圈子ID
        string description; // 商品描述
        string validity;    // 有效期
        string stock;       // 库存
        string categoryId;  // 分类ID
    }

    struct Member {
        string did; // 企业DID
        string orgName; // 企业名称
        string socialCreditCode; // 社会信用代码
    }
}
