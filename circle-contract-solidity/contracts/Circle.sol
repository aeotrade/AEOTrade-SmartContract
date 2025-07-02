// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "./CircleStructs.sol";

contract CircleContract {
    using CircleStructs for CircleStructs.Circle;
    using CircleStructs for CircleStructs.Application;
    using CircleStructs for CircleStructs.Product;
    using CircleStructs for CircleStructs.Member;

    address public admin;

    // Mappings
    mapping(string => CircleStructs.Circle) private _circles;
    string[] private _circleIds;

    mapping(string => CircleStructs.Application[]) private _applications;
    mapping(string => mapping(string => uint256)) private _applicationIndex;

    mapping(string => mapping(string => CircleStructs.Member)) private _members;
    mapping(string => string[]) private _memberDIDs;

    mapping(string => CircleStructs.Product) private _products;
    string[] private _allProductIds;

    // Events
    event CircleCreated(string circleId, string ownerDID, string ownerOrgName);
    event ApplicationSubmitted(string circleId, string applicantDID);
    event ApplicationApproved(string circleId, string applicantDID);
    event ApplicationRejected(string circleId, string applicantDID);
    event MemberLeft(string circleId, string memberDID);
    event OwnershipTransferred(string circleId, string newOwnerDID);
    event ProductCreated(string productId, string circleId, string ownerDID);
    event ProductApproved(string productId);
    event ProductEdited(string productId);
    event ProductShelfStatusChanged(string productId, bool onShelf);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }

    modifier onlyCircleOwner(string memory circleId, string memory did) {
        require(
            keccak256(abi.encodePacked(_circles[circleId].ownerDID)) == keccak256(abi.encodePacked(did)),
            "Caller is not the circle owner"
        );
        _;
    }

    modifier isCircleMember(string memory circleId, string memory memberDID) {
        require(bytes(_members[circleId][memberDID].did).length > 0, "Caller is not a member of this circle");
        _;
    }

     modifier circleExists(string memory circleId) {
        require(bytes(_circles[circleId].creatorDID).length > 0, "Circle does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /// @notice 创建一个新圈子
    /// @param circleId 圈子ID
    /// @param name 圈子名称
    /// @param description 圈子描述
    /// @param ownerDID 创建者DID
    /// @param ownerOrgName 创建者组织名称
    function createCircle(
        string memory circleId,
        string memory name,
        string memory description,
        string memory ownerDID,
        string memory ownerOrgName
    ) public {
        require(bytes(_circles[circleId].creatorDID).length == 0, "Circle ID already exists");
        _circles[circleId] = CircleStructs.Circle({
            id: circleId,
            name: name,
            description: description,
            ownerDID: ownerDID, // Initially, owner is the creator
            ownerOrgName: ownerOrgName,
            creatorDID: ownerDID,
            creatorOrgName: ownerOrgName,
            creationTime: block.timestamp,
            disabled: false
        });
        _circleIds.push(circleId);
        // 自动把owner加入成员列表
        _members[circleId][ownerDID] = CircleStructs.Member({
            did: ownerDID,
            orgName: ownerOrgName,
            socialCreditCode: ""
        });
        _memberDIDs[circleId].push(ownerDID);
        emit CircleCreated(circleId, ownerDID, ownerOrgName);
    }

    /// @notice 转移圈子所有权
    /// @param circleId 圈子ID
    /// @param currentOwnerDID 当前所有者的DID
    /// @param newOwnerDID 新所有者的DID
    /// @param newOwnerOrgName 新所有者的组织名称
    function transferCircleOwnership(
        string memory circleId,
        string memory currentOwnerDID,
        string memory newOwnerDID,
        string memory newOwnerOrgName
    ) public circleExists(circleId) onlyCircleOwner(circleId, currentOwnerDID) {
        require(bytes(newOwnerDID).length > 0, "New owner DID cannot be empty");

        _circles[circleId].ownerDID = newOwnerDID;
        _circles[circleId].ownerOrgName = newOwnerOrgName;
        emit OwnershipTransferred(circleId, newOwnerDID);
    }

    /// @notice 申请加入圈子
    function applyToJoinCircle(
        string memory circleId,
        string memory applicantDID,
        string memory orgName,
        string memory socialCreditCode
    ) public circleExists(circleId) {
        require(!_circles[circleId].disabled, "Circle is disabled, cannot join");
        require(bytes(_members[circleId][applicantDID].did).length == 0, "Already a member");
        require(_applicationIndex[circleId][applicantDID] == 0, "Application already submitted");
        CircleStructs.Application memory newApplication = CircleStructs.Application({
            applicantDID: applicantDID,
            orgName: orgName,
            socialCreditCode: socialCreditCode,
            status: CircleStructs.ApplicationStatus.Pending
        });
        _applications[circleId].push(newApplication);
        _applicationIndex[circleId][applicantDID] = _applications[circleId].length;
        emit ApplicationSubmitted(circleId, applicantDID);
    }

    /// @notice 圈主批准申请
    function approveApplication(
        string memory circleId,
        string memory ownerDID,
        string memory applicantDID
    ) public circleExists(circleId) onlyCircleOwner(circleId, ownerDID) {
        uint256 appIndex = _applicationIndex[circleId][applicantDID];
        require(appIndex > 0, "Application does not exist");

        CircleStructs.Application storage application = _applications[circleId][appIndex - 1];
        require(application.status != CircleStructs.ApplicationStatus.Approved, "Application already approved");

        application.status = CircleStructs.ApplicationStatus.Approved;

        _members[circleId][applicantDID] = CircleStructs.Member({
            did: applicantDID,
            orgName: application.orgName,
            socialCreditCode: application.socialCreditCode
        });
        _memberDIDs[circleId].push(applicantDID);

        emit ApplicationApproved(circleId, applicantDID);
    }

    /// @notice 圈主拒绝申请
     function rejectApplication(
        string memory circleId,
        string memory ownerDID,
        string memory applicantDID
    ) public circleExists(circleId) onlyCircleOwner(circleId, ownerDID) {
        uint256 appIndex = _applicationIndex[circleId][applicantDID];
        require(appIndex > 0, "Application does not exist");

        CircleStructs.Application storage application = _applications[circleId][appIndex - 1];
        require(application.status == CircleStructs.ApplicationStatus.Pending, "Application not pending");

        application.status = CircleStructs.ApplicationStatus.Rejected;

        emit ApplicationRejected(circleId, applicantDID);
    }

    /// @notice 成员退出圈子
    function exitCircle(
        string memory circleId,
        string memory memberDID
    ) public circleExists(circleId) isCircleMember(circleId, memberDID) {
        // 下架该成员在本圈子发布的所有商品
        for (uint i = 0; i < _allProductIds.length; i++) {
            string memory productId = _allProductIds[i];
            CircleStructs.Product storage product = _products[productId];
            if (
                keccak256(bytes(product.circleId)) == keccak256(bytes(circleId)) &&
                keccak256(bytes(product.ownerDID)) == keccak256(bytes(memberDID)) &&
                product.onShelf
            ) {
                product.onShelf = false;
                emit ProductShelfStatusChanged(productId, false);
            }
        }
        // If owner
        if (keccak256(bytes(_circles[circleId].ownerDID)) == keccak256(bytes(memberDID))) {
            if (_memberDIDs[circleId].length > 1) {
                revert("Owner must transfer ownership before exit if there are other members");
            }
            // owner is last member, allow exit and disable circle
            _circles[circleId].disabled = true;
        }
        delete _members[circleId][memberDID];
        string[] storage dids = _memberDIDs[circleId];
        for (uint i = 0; i < dids.length; i++) {
            if (keccak256(abi.encodePacked(dids[i])) == keccak256(abi.encodePacked(memberDID))) {
                dids[i] = dids[dids.length - 1];
                dids.pop();
                break;
            }
        }
        emit MemberLeft(circleId, memberDID);
    }

    // 内部函数：构建申请字符串
    function _buildApplicationString(CircleStructs.Application memory app) internal pure returns (string memory) {
        string memory result = "";
        result = string(abi.encodePacked(result, "applicantDID:", app.applicantDID));
        result = string(abi.encodePacked(result, ";orgName:", app.orgName));
        result = string(abi.encodePacked(result, ";socialCreditCode:", app.socialCreditCode));
        result = string(abi.encodePacked(result, ";status:", _uint2str(uint256(app.status))));
        return result;
    }

    // 内部函数：构建成员字符串
    function _buildMemberString(CircleStructs.Member memory member) internal pure returns (string memory) {
        string memory result = "";
        result = string(abi.encodePacked(result, "did:", member.did));
        result = string(abi.encodePacked(result, ";orgName:", member.orgName));
        result = string(abi.encodePacked(result, ";socialCreditCode:", member.socialCreditCode));
        return result;
    }

    // 内部函数：构建商品字符串
    function _buildProductString(CircleStructs.Product memory product) internal pure returns (string memory) {
        string memory s1 = string(abi.encodePacked("id:", product.id, ";"));
        string memory s2 = string(abi.encodePacked("name:", product.name, ";"));
        string memory s3 = string(abi.encodePacked("price:", product.price, ";"));
        string memory s4 = string(abi.encodePacked("productType:", _uint2str(uint256(product.productType)), ";"));
        string memory s5 = string(abi.encodePacked("onShelf:", product.onShelf ? "1" : "0", ";"));
        string memory s6 = string(abi.encodePacked("ipfsHash:", product.ipfsHash, ";"));
        string memory s7 = string(abi.encodePacked("auditStatus:", _uint2str(uint256(product.auditStatus)), ";"));
        string memory s8 = string(abi.encodePacked("ownerDID:", product.ownerDID, ";"));
        string memory s9 = string(abi.encodePacked("circleId:", product.circleId, ";"));
        string memory s10 = string(abi.encodePacked("description:", product.description, ";"));
        string memory s11 = string(abi.encodePacked("validity:", product.validity, ";"));
        string memory s12 = string(abi.encodePacked("stock:", product.stock));
        return string(abi.encodePacked(s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12));
    }

    // 内部函数：构建圈子字符串
    function _buildCircleString(CircleStructs.Circle memory circle) internal pure returns (string memory) {
        string memory result = "";
        result = string(abi.encodePacked(result, "id:", circle.id));
        result = string(abi.encodePacked(result, ";name:", circle.name));
        result = string(abi.encodePacked(result, ";ownerDID:", circle.ownerDID));
        result = string(abi.encodePacked(result, ";ownerOrgName:", circle.ownerOrgName));
        result = string(abi.encodePacked(result, ";creatorDID:", circle.creatorDID));
        result = string(abi.encodePacked(result, ";creatorOrgName:", circle.creatorOrgName));
        result = string(abi.encodePacked(result, ";creationTime:", _uint2str(circle.creationTime)));
        result = string(abi.encodePacked(result, ";disabled:", circle.disabled ? "1" : "0"));
        return result;
    }

    // 圈子JSON
    function _buildCircleJSONString(CircleStructs.Circle memory circle) internal pure returns (string memory) {
        string memory s1 = string(abi.encodePacked(
            "{",
            '\"id\":\"', circle.id, '\",',
            '\"name\":\"', circle.name, '\",'
        ));
        string memory s2 = string(abi.encodePacked(
            '\"description\":\"', circle.description, '\",',
            '\"ownerDID\":\"', circle.ownerDID, '\",'
        ));
        string memory s3 = string(abi.encodePacked(
            '\"ownerOrgName\":\"', circle.ownerOrgName, '\",',
            '\"creatorDID\":\"', circle.creatorDID, '\",'
        ));
        string memory s4 = string(abi.encodePacked(
            '\"creatorOrgName\":\"', circle.creatorOrgName, '\",',
            '\"creationTime\":\"', _uint2str(circle.creationTime), '\",'
        ));
        string memory s5 = string(abi.encodePacked(
            '\"disabled\":\"', circle.disabled ? "1" : "0", '\"',
            "}"
        ));
        return string(abi.encodePacked(s1, s2, s3, s4, s5));
    }

    // 成员JSON
    function _buildMemberJSONString(CircleStructs.Member memory member) internal pure returns (string memory) {
        string memory s1 = string(abi.encodePacked(
            "{",
            '\"did\":\"', member.did, '\",',
            '\"orgName\":\"', member.orgName, '\",'
        ));
        string memory s2 = string(abi.encodePacked(
            '\"socialCreditCode\":\"', member.socialCreditCode, '\"',
            "}"
        ));
        return string(abi.encodePacked(s1, s2));
    }

    // 申请JSON
    function _buildApplicationJSONString(CircleStructs.Application memory app) internal pure returns (string memory) {
        string memory s1 = string(abi.encodePacked(
            "{",
            '\"applicantDID\":\"', app.applicantDID, '\",',
            '\"orgName\":\"', app.orgName, '\",'
        ));
        string memory s2 = string(abi.encodePacked(
            '\"socialCreditCode\":\"', app.socialCreditCode, '\",',
            '\"status\":\"', _uint2str(uint256(app.status)), '\"',
            "}"
        ));
        return string(abi.encodePacked(s1, s2));
    }

    // 商品JSON
    function _buildProductJSONString(CircleStructs.Product memory product) internal pure returns (string memory) {
        string memory s1 = string(abi.encodePacked(
            "{",
            '\"id\":\"', product.id, '\",',
            '\"name\":\"', product.name, '\",'
        ));
        string memory s2 = string(abi.encodePacked(
            '\"price\":\"', product.price, '\",',
            '\"productType\":\"', _uint2str(uint256(product.productType)), '\",'
        ));
        string memory s3 = string(abi.encodePacked(
            '\"onShelf\":\"', product.onShelf ? "1" : "0", '\",',
            '\"ipfsHash\":\"', product.ipfsHash, '\",'
        ));
        string memory s4 = string(abi.encodePacked(
            '\"auditStatus\":\"', _uint2str(uint256(product.auditStatus)), '\",',
            '\"ownerDID\":\"', product.ownerDID, '\",'
        ));
        string memory s5 = string(abi.encodePacked(
            '\"circleId\":\"', product.circleId, '\",',
            '\"description\":\"', product.description, '\",',
            '\"validity\":\"', product.validity, '\",',
            '\"stock\":\"', product.stock, '\"',
            "}"
        ));
        return string(abi.encodePacked(s1, s2, s3, s4, s5));
    }

    function getApplications(string memory circleId, uint256 page, uint256 pageSize)
        public
        view
        circleExists(circleId)
        returns (string memory)
    {
        CircleStructs.Application[] storage appStorage = _applications[circleId];
        uint256 total = appStorage.length;
        if (pageSize == 0 || page == 0 || total == 0) {
            return "[]";
        }
        uint256 startIndex = (page - 1) * pageSize;
        if (startIndex >= total) {
            return "[]";
        }
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > total) {
            endIndex = total;
        }
        string memory result = "[";
        for(uint i = startIndex; i < endIndex; i++){
            if (i > startIndex) {
                result = string(abi.encodePacked(result, ","));
            }
            result = string(abi.encodePacked(result, _buildApplicationJSONString(appStorage[i])));
        }
        result = string(abi.encodePacked(result, "]"));
        return result;
    }

    function getCircleMembers(string memory circleId, uint256 page, uint256 pageSize)
        public
        view
        circleExists(circleId)
        returns (string memory)
    {
        string[] storage dids = _memberDIDs[circleId];
        uint256 total = dids.length;
        if (pageSize == 0 || page == 0 || total == 0) {
            return "[]";
        }
        uint256 startIndex = (page - 1) * pageSize;
        if (startIndex >= total) {
            return "[]";
        }
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > total) {
            endIndex = total;
        }
        string memory result = "[";
        for (uint i = startIndex; i < endIndex; i++) {
            if (i > startIndex) {
                result = string(abi.encodePacked(result, ","));
            }
            result = string(abi.encodePacked(result, _buildMemberJSONString(_members[circleId][dids[i]])));
        }
        result = string(abi.encodePacked(result, "]"));
        return result;
    }

    function getAllProducts(uint256 page, uint256 pageSize) public view returns (string memory) {
        uint256 total = _allProductIds.length;
        if (pageSize == 0 || page == 0 || total == 0) {
            return "[]";
        }
        uint256 startIndex = (page - 1) * pageSize;
        if (startIndex >= total) {
            return "[]";
        }
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > total) {
            endIndex = total;
        }
        string memory result = "[";
        for (uint i = startIndex; i < endIndex; i++) {
            string memory productId = _allProductIds[i];
            if (i > startIndex) {
                result = string(abi.encodePacked(result, ","));
            }
            result = string(abi.encodePacked(result, _buildProductJSONString(_products[productId])));
        }
        result = string(abi.encodePacked(result, "]"));
        return result;
    }

    function getAllCircles(uint256 page, uint256 pageSize)
        public
        view
        onlyAdmin
        returns (string memory)
    {
        uint256 total = _circleIds.length;
        if (pageSize == 0 || page == 0 || total == 0) {
            return "[]";
        }
        uint256 startIndex = (page - 1) * pageSize;
        if (startIndex >= total) {
            return "[]";
        }
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > total) {
            endIndex = total;
        }
        string memory result = "[";
        for (uint i = startIndex; i < endIndex; i++) {
            if (i > startIndex) {
                result = string(abi.encodePacked(result, ","));
            }
            result = string(abi.encodePacked(result, _buildCircleJSONString(_circles[_circleIds[i]])));
        }
        result = string(abi.encodePacked(result, "]"));
        return result;
    }

    /// @notice 将uint转换为string
    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k -= 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    /// @notice (Admin) 获取指定圈子的成员列表
    function getMembersInCircleForAdmin(string memory circleId, uint256 page, uint256 pageSize)
        public
        view
        onlyAdmin
        returns (string memory)
    {
        return getCircleMembers(circleId, page, pageSize);
    }

    /// @notice 圈子成员发布商品
    function createProduct(
        string memory productId,
        string memory circleId,
        string memory memberDID,
        string memory name,
        string memory price,
        CircleStructs.ProductType productType,
        string memory ipfsHash,
        string memory description,
        string memory validity,
        string memory stock,
        string memory categoryId
    ) public circleExists(circleId) isCircleMember(circleId, memberDID) {
        require(bytes(_products[productId].id).length == 0, "Product ID already exists");
        _products[productId] = CircleStructs.Product({
            id: productId,
            name: name,
            price: price,
            productType: productType,
            onShelf: false,
            ipfsHash: ipfsHash,
            auditStatus: CircleStructs.AuditStatus.Pending,
            ownerDID: memberDID,
            circleId: circleId,
            description: description,
            validity: validity,
            stock: stock,
            categoryId: categoryId
        });

        _allProductIds.push(productId);
        emit ProductCreated(productId, circleId, memberDID);
    }

    /// @notice 圈主审核商品
    function approveProduct(
        string memory circleId,
        string memory ownerDID,
        string memory productId
    ) public circleExists(circleId) onlyCircleOwner(circleId, ownerDID) {
        require(bytes(_products[productId].id).length > 0, "Product does not exist");
        require(_products[productId].auditStatus == CircleStructs.AuditStatus.Pending, "Product not pending approval");

        _products[productId].auditStatus = CircleStructs.AuditStatus.Approved;
        emit ProductApproved(productId);
    }

    /// @notice 编辑商品
    function editProduct(
        string memory productId,
        string memory memberDID,
        string memory newName,
        string memory newPrice,
        string memory newIpfsHash,
        string memory newDescription,
        string memory newValidity,
        string memory newStock,
        string memory newCategoryId
    ) public {
        CircleStructs.Product storage product = _products[productId];
        require(bytes(product.id).length > 0, "Product does not exist");
        require(keccak256(abi.encodePacked(product.ownerDID)) == keccak256(abi.encodePacked(memberDID)), "Not product owner");

        product.name = newName;
        product.price = newPrice;
        product.ipfsHash = newIpfsHash;
        product.description = newDescription;
        product.validity = newValidity;
        product.stock = newStock;
        product.categoryId = newCategoryId;

        // Editing a product may require re-approval
        product.auditStatus = CircleStructs.AuditStatus.Pending;
        product.onShelf = false;

        emit ProductEdited(productId);
    }

    /// @notice 上下架商品
    function setProductOnShelf(
        string memory productId,
        string memory memberDID,
        bool onShelf
    ) public {
        CircleStructs.Product storage product = _products[productId];
        require(bytes(product.id).length > 0, "Product does not exist");
        require(keccak256(abi.encodePacked(product.ownerDID)) == keccak256(abi.encodePacked(memberDID)), "Not product owner");
        require(product.auditStatus == CircleStructs.AuditStatus.Approved, "Product must be approved to be set on shelf");

        product.onShelf = onShelf;
        emit ProductShelfStatusChanged(productId, onShelf);
    }

    /// @notice 根据商品ID获取商品详情
    function getProductById(string memory productId) public view returns (CircleStructs.Product memory) {
        require(bytes(_products[productId].id).length > 0, "Product does not exist");
        return _products[productId];
    }

    // 分页工具
    function _getPageInfo(uint256 total, uint256 pageSize) internal pure returns (uint256 totalPages) {
        if (pageSize == 0) return 0;
        return (total + pageSize - 1) / pageSize;
    }
}
