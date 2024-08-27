# Deployment of pool

```mermaid
sequenceDiagram
  participant line_4 as user
  participant line_1 as factory
  participant line_2 as deployer
  participant line_3 as uniswapv3pool
 
  line_4 ->> line_1: createPool
  line_1 ->> line_2: deploy
  line_2 ->> line_3: new pool
```



 