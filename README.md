# MLDataSyncPool

由于做的IM里有 根据userID异步更新用户信息需求 而产生的数据同步池。
还有其他地方，例如像微信的朋友圈啊，头像昵称也可能是异步更新的。
很遗憾除了用户信息，暂时还没有想到其他的使用场景。

##用户信息数据同步机制简介：

###原则
- 拉取请求支持多keys参数，有多少对应的结果就返回多少，并非发现有异常key就啥都不返回或拉取失败。
- 本地对应userID的存储若是空detail的话，就要尽可能的立即更新。
- 本地对应userID的存储若不是空detail的话没必要更新的太及时，在可以接受的前提下用户能感知就可以，以减少拉取请求次数。
- 尽可能的整合同步keys一块进行拉取请求，以减少拉取请求次数。
- 同一个key同时只能进行一次拉取。

###demo里的一些设定
- 一个User的数据同步任务投递成功的前提是其为空detail，或者非空detail但被标记dirty且距离上次同步超过一定时间。
- 任何同步任务的投递成功与否都受到上述规则的限制，注意这一点，下面的描述“投递任务”也都受到这个限制，就不一一说明了。

- 数据同步任务分为两种，一种是立即任务，一种是延迟任务，延迟任务投递成功后不会立即执行拉取，会一直等到N秒内没有新的任务进来才执行拉取，保证尽可能的整合任务以尽可能减少拉取请求次数。

- 如果发现一组新的UserIDs，立即对他们进行投递数据同步任务。例如在IM里发现了一个新的群组。
- 只有当某User绑定的View显示的时候才会去投递数据同步任务。
- 每个同步任务投递成功之后都去检查当前池子里是否有立即任务，若有则立即执行拉取，否则去执行延迟递归检测最终执行拉取。
- 延迟任务拉取同时只会有一个在执行。
- 一个User在同步N次之后都失败的话就不会再进行同步。
- demo里默认在每次程序active后会对所有User存储打上dirty标记，等到显示的时候才有可能让数据同步任务投递成功，并且会重置掉failCount，之前失败的任务还有重新同步的可能。 同时也会立即去投递所有空detail UserID的任务。

。。。。。

有点乱，基本就这些。。