# circle-contract-solidity



## Project setup
```
npm install

npm install solcjs -g
```


## build
```
solcjs --bin --abi --optimize contracts/Circle.sol contracts/CircleStructs.sol

```


### 部署合约

```shell

$ ./cmc client contract user create 
--contract-name=contract_circle
--runtime-type=EVM 
--byte-code-path=./testdata/circle-demo/contracts_Circle.bin 
--abi-file-path=./testdata/circle-demo/contracts_Circle.abi 
--version=1.0 --sdk-conf-path=./testdata/sdk_config.yml 
--admin-key-file-paths=./testdata/crypto-config/aeotrade/certs/user/aeotradeuser/aeotradeuser.sign.key,
./testdata/crypto-config/beijingcustoms/certs/user/beijingcustomsuser/beijingcustomsuser.sign.key,
./testdata/crypto-config/portassociation/certs/user/portassociationuser/portassociationuser.sign.key,
./testdata/crypto-config/singlewindow/certs/user/singlewindowuser/singlewindowuser.sign.key 
--admin-crt-file-paths=./testdata/crypto-config/aeotrade/certs/user/aeotradeuser/aeotradeuser.sign.crt,
./testdata/crypto-config/beijingcustoms/certs/user/beijingcustomsuser/beijingcustomsuser.sign.crt,
./testdata/crypto-config/portassociation/certs/user/portassociationuser/portassociationuser.sign.crt,
./testdata/crypto-config/singlewindow/certs/user/singlewindowuser/singlewindowuser.sign.crt 
--sync-result=true

```
### 主要功能体验
create circle：

```shell

$ ./cmc client contract user invoke \
--contract-name=contract_circle \
--method=getAllCircles \
--sdk-conf-path=./testdata/sdk_config.yml \
--params="[{\"page\": \"1\"},{\"pageSize\": \"10\"}]" \
--sync-result=true \
--abi-file-path=./testdata/circle-demo/contracts_Circle.abi

```

### NOTICE：

This software is licensed under the GNU Lesser General Public License (LGPL) version 3.0 or later. However, it is not permitted to use this software for commercial purposes without explicit permission from the copyright holder.
If the above restrictions are violated, all commercial profits generated during unauthorized commercial use shall belong to the copyright holder.
The copyright holder reserves the right to pursue legal liability against infringers through legal means, including but not limited to demanding the cessation of infringement and compensation for losses suffered as a result of infringement.
本软件根据GNU较宽松通用公共许可证（LGPL）3.0或更高版本获得许可。但是，未经版权所有者明确许可，不得将本软件用于商业目的。
若违反上述限制，在未经授权的商业化使用过程中所产生的一切商业收益，均归版权所有者。
版权所有者保留通过法律途径追究侵权者法律责任的权利，包括但不限于要求停止侵权行为、赔偿因侵权行为所遭受的损失等。


