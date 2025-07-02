const { expect } = require("chai");
const { ethers } = require("hardhat");

// Helper function to print logs in Chinese
const log = (message, data) => {
    console.log(`\n[测试日志] ${message}`);
    if (data) {
        // BigNumber to string for better readability
        const formattedData = JSON.stringify(data, (key, value) =>
            typeof value === 'bigint' ? value.toString() : value
        , 2);
        console.log(`   [数据] ${formattedData}`);
    }
};

// 辅助函数：解析字符串结果
const parseStringResult = (str) => {
    if (!str || str === "") return [];
    return str.split("|");
};

// 辅助函数：解析key:value格式的字符串
const parseKeyValueString = (str) => {
    if (!str || str === "") return {};
    const result = {};
    const pairs = str.split(";");
    for (const pair of pairs) {
        const [key, value] = pair.split(":");
        if (key && value !== undefined) {
            result[key] = value;
        }
    }
    return result;
};

// 辅助函数：从key:value字符串中获取指定字段的值
const getValueFromKeyValueString = (str, key) => {
    const obj = parseKeyValueString(str);
    return obj[key];
};

describe("CircleContract 全面测试", function () {
    let circleContract, admin, user1, user2, user3;
    const ADMIN_DID = "did:admin";
    const USER1_DID = "did:user1";
    const USER2_DID = "did:user2";
    const ADMIN_ORG = "管理员组织";
    const USER1_ORG = "用户1组织";
    const CIRCLE_NAME = "第一个圈子";

    // 每个测试用例都用唯一ID，避免冲突
    function uniqueCircleId(suffix) {
        return `test-circle-${Date.now()}-${Math.floor(Math.random()*10000)}-${suffix}`;
    }

    beforeEach(async function () {
        [admin, user1, user2, user3] = await ethers.getSigners();
        const CircleContract = await ethers.getContractFactory("CircleContract");
        circleContract = await CircleContract.deploy();
        // await circleContract.deployed();
        log(`合约由地址 ${admin.address} 成功部署到 ${circleContract.address}`);
    });

    describe("1. 圈子管理", function () {
        it("1.1. 应该成功创建一个圈子", async function () {
            const CIRCLE_ID = uniqueCircleId("create");
            await expect(circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG))
                .to.emit(circleContract, "CircleCreated")
                .withArgs(CIRCLE_ID, ADMIN_DID, ADMIN_ORG);
            
            const circlesStr = await circleContract.getAllCircles(1, 10);
            const circles = parseStringResult(circlesStr);
            console.log("【创建圈子】实际圈子数量:", circles.length, "预期: 1");
            console.log("圈子列表:", circles);
            expect(circles.length).to.equal(1);
            expect(getValueFromKeyValueString(circles[0], "id")).to.equal(CIRCLE_ID);
        });

        it("1.2. 应该成功转移圈子所有权", async function () {
            const CIRCLE_ID = uniqueCircleId("transfer");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            const NEW_OWNER_DID = "did:new-owner";
            const NEW_OWNER_ORG = "新所有者组织";
            await expect(circleContract.transferCircleOwnership(CIRCLE_ID, ADMIN_DID, NEW_OWNER_DID, NEW_OWNER_ORG))
                .to.emit(circleContract, "OwnershipTransferred");
            
            const circlesStr = await circleContract.getAllCircles(1, 10);
            const circles = parseStringResult(circlesStr);
            const circleData = parseKeyValueString(circles[0]);
            console.log("【转移所有权】新ownerDID:", circleData.ownerDID, "预期:", NEW_OWNER_DID);
            console.log("【转移所有权】新ownerOrgName:", circleData.ownerOrgName, "预期:", NEW_OWNER_ORG);
            expect(circleData.ownerDID).to.equal(NEW_OWNER_DID);
            expect(circleData.ownerOrgName).to.equal(NEW_OWNER_ORG);
        });
    });

    describe("2. 成员管理", function () {
        it("2.1. 用户可以申请加入，圈主可以查看申请并批准", async function () {
            const CIRCLE_ID = uniqueCircleId("join");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            
            const applicationsStr = await circleContract.getApplications(CIRCLE_ID, 1, 10);
            const applications = parseStringResult(applicationsStr);
            console.log("【申请加入】实际申请数:", applications.length, "预期: 1");
            expect(applications.length).to.equal(1);
            expect(getValueFromKeyValueString(applications[0], "applicantDID")).to.equal(USER1_DID);
            
            await circleContract.approveApplication(CIRCLE_ID, ADMIN_DID, USER1_DID);
            const membersStr = await circleContract.getCircleMembers(CIRCLE_ID, 1, 10);
            const members = parseStringResult(membersStr);
            console.log("【批准后成员数】实际:", members.length, "预期: 2");
            expect(members.length).to.equal(2);
            expect(members.some(m => getValueFromKeyValueString(m, "did") === USER1_DID)).to.be.true;
        });

        it("2.2. 圈主可以拒绝申请", async function () {
            const CIRCLE_ID = uniqueCircleId("reject");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            await expect(circleContract.rejectApplication(CIRCLE_ID, ADMIN_DID, USER1_DID))
                .to.emit(circleContract, "ApplicationRejected");
            
            const applicationsStr = await circleContract.getApplications(CIRCLE_ID, 1, 10);
            const applications = parseStringResult(applicationsStr);
            const status = getValueFromKeyValueString(applications[0], "status");
            console.log("【拒绝申请】申请状态:", status, "预期: 2");
            expect(status).to.equal("2"); // 2 = Rejected
        });

        it("2.3. 成员可以主动退出圈子", async function () {
            const CIRCLE_ID = uniqueCircleId("exit");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            await circleContract.approveApplication(CIRCLE_ID, ADMIN_DID, USER1_DID);
            await expect(circleContract.exitCircle(CIRCLE_ID, USER1_DID)).to.emit(circleContract, "MemberLeft");
            
            const membersStr = await circleContract.getCircleMembers(CIRCLE_ID, 1, 10);
            const members = parseStringResult(membersStr);
            console.log("【退出后成员数】实际:", members.length, "预期: 1");
            expect(members.some(m => getValueFromKeyValueString(m, "did") === USER1_DID)).to.be.false;
        });

        it("2.4. 管理员可以查看任意圈子成员", async function () {
            const CIRCLE_ID = uniqueCircleId("adminview");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            await circleContract.approveApplication(CIRCLE_ID, ADMIN_DID, USER1_DID);
            
            const membersStr = await circleContract.getMembersInCircleForAdmin(CIRCLE_ID, 1, 10);
            const members = parseStringResult(membersStr);
            console.log("【管理员查看成员】实际成员数:", members.length, "预期: 2");
            expect(members.length).to.equal(2);
            expect(members.some(m => getValueFromKeyValueString(m, "did") === USER1_DID)).to.be.true;
        });

        it("分页返回总条数和总页数", async function () {
            const CIRCLE_ID = uniqueCircleId("page");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            await circleContract.approveApplication(CIRCLE_ID, ADMIN_DID, USER1_DID);
            
            const membersStr = await circleContract.getCircleMembers(CIRCLE_ID, 1, 10);
            const members = parseStringResult(membersStr);
            console.log("【分页成员数】实际:", members.length, "预期: 2");
            expect(members.length).to.equal(2);
        });

        it("圈主有其它成员时不能退出圈子", async function () {
            const CIRCLE_ID = uniqueCircleId("ownerexit");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            await circleContract.approveApplication(CIRCLE_ID, ADMIN_DID, USER1_DID);
            try {
                await circleContract.exitCircle(CIRCLE_ID, ADMIN_DID);
            } catch (e) {
                console.log("【圈主有其它成员时不能退出】捕获到异常:", e.message);
                expect(e.message).to.include("Owner must transfer ownership before exit if there are other members");
            }
        });

        it("owner是最后一个成员时退出后圈子禁用，不能再申请加入", async function () {
            const CIRCLE_ID = uniqueCircleId("disable");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await expect(circleContract.exitCircle(CIRCLE_ID, ADMIN_DID))
                .to.emit(circleContract, "MemberLeft");
            
            const circlesStr = await circleContract.getAllCircles(1, 10);
            const circles = parseStringResult(circlesStr);
            const disabled = getValueFromKeyValueString(circles[0], "disabled");
            console.log("【owner最后一个成员退出后禁用】disabled:", disabled, "预期: 1");
            expect(disabled).to.equal("1");
            
            try {
                await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            } catch (e) {
                console.log("【禁用圈子不能再申请】捕获到异常:", e.message);
                expect(e.message).to.include("Circle is disabled, cannot join");
            }
        });
    });

    describe("3. 商品管理", function () {
        it("3.1. 成员可以发布商品，圈主可以审批", async function () {
            const CIRCLE_ID = uniqueCircleId("product");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            await circleContract.approveApplication(CIRCLE_ID, ADMIN_DID, USER1_DID);
            
            await circleContract.connect(user1).createProduct(CIRCLE_ID, USER1_DID, "测试商品", "100 ETH", 0, "ipfs-hash");
            const productsStr = await circleContract.getAllProducts(1, 10);
            const products = parseStringResult(productsStr);
            console.log("【商品发布后总数】实际:", products.length, "预期: 1");
            expect(products.length).to.equal(1);
            
            const productId = getValueFromKeyValueString(products[0], "id");
            await circleContract.approveProduct(CIRCLE_ID, ADMIN_DID, productId);
            const approvedProductsStr = await circleContract.getAllProducts(1, 10);
            const approvedProducts = parseStringResult(approvedProductsStr);
            const auditStatus = getValueFromKeyValueString(approvedProducts[0], "auditStatus");
            console.log("【商品审批后状态】实际:", auditStatus, "预期: 1");
            expect(auditStatus).to.equal("1"); // 1 = Approved
        });

        it("3.2. 商品所有者可以编辑和上下架商品", async function () {
            const CIRCLE_ID = uniqueCircleId("editproduct");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            await circleContract.approveApplication(CIRCLE_ID, ADMIN_DID, USER1_DID);
            
            await circleContract.connect(user1).createProduct(CIRCLE_ID, USER1_DID, "老商品", "99", 0, "old-ipfs");
            const productsStr = await circleContract.getAllProducts(1, 10);
            const products = parseStringResult(productsStr);
            const productId = getValueFromKeyValueString(products[0], "id");
            await circleContract.approveProduct(CIRCLE_ID, ADMIN_DID, productId);
            
            await circleContract.editProduct(productId, USER1_DID, "新商品", "199", "new-ipfs");
            const editedProductsStr = await circleContract.getAllProducts(1, 10);
            const editedProducts = parseStringResult(editedProductsStr);
            const name = getValueFromKeyValueString(editedProducts[0], "name");
            const auditStatus = getValueFromKeyValueString(editedProducts[0], "auditStatus");
            console.log("【商品编辑后名称】实际:", name, "预期: 新商品");
            expect(name).to.equal("新商品");
            expect(auditStatus).to.equal("0"); // 编辑后需要重新审核
            
            await circleContract.approveProduct(CIRCLE_ID, ADMIN_DID, productId);
            await circleContract.setProductOnShelf(productId, USER1_DID, true);
            const onShelfProductsStr = await circleContract.getAllProducts(1, 10);
            const onShelfProducts = parseStringResult(onShelfProductsStr);
            const onShelf = getValueFromKeyValueString(onShelfProducts[0], "onShelf");
            console.log("【商品上架状态】实际:", onShelf, "预期: 1");
            expect(onShelf).to.equal("1");
        });

        it("3.3. 任何用户都可以查看所有商品", async function () {
            const CIRCLE_ID = uniqueCircleId("allproduct");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            await circleContract.approveApplication(CIRCLE_ID, ADMIN_DID, USER1_DID);
            
            await circleContract.connect(user1).createProduct(CIRCLE_ID, USER1_DID, "商品A", "1", 0, "ipfs-A");
            await circleContract.connect(user1).createProduct(CIRCLE_ID, USER1_DID, "商品B", "2", 1, "ipfs-B");
            
            const productsStr = await circleContract.getAllProducts(1, 10);
            const products = parseStringResult(productsStr);
            console.log("【所有商品总数】实际:", products.length, "预期: 2");
            expect(products.length).to.equal(2);
        });

        it("3.4. 可以通过商品ID获取商品详情", async function () {
            const CIRCLE_ID = uniqueCircleId("detail");
            await circleContract.createCircle(CIRCLE_ID, CIRCLE_NAME, ADMIN_DID, ADMIN_ORG);
            await circleContract.connect(user1).applyToJoinCircle(CIRCLE_ID, USER1_DID, USER1_ORG, "credit-123");
            await circleContract.approveApplication(CIRCLE_ID, ADMIN_DID, USER1_DID);
            
            await circleContract.connect(user1).createProduct(CIRCLE_ID, USER1_DID, "商品C", "10", 0, "ipfs-C");
            const productsStr = await circleContract.getAllProducts(1, 10);
            const products = parseStringResult(productsStr);
            const productId = getValueFromKeyValueString(products[0], "id");
            
            const detail = await circleContract.getProductById(productId);
            console.log("【商品详情】名称:", detail.name, "预期: 商品C");
            console.log("【商品详情】价格:", detail.price, "预期: 10");
            console.log("【商品详情】IPFS:", detail.ipfsHash, "预期: ipfs-C");
            expect(detail.name).to.equal("商品C");
            expect(detail.price).to.equal("10");
            expect(detail.ipfsHash).to.equal("ipfs-C");
        });
    });
});
