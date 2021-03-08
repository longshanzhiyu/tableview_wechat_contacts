# tableview_wechat_contacts

微信通讯录页面UITableView细节探究

写在前面的
最近做了一个城市选择列表页的需求，大概是一个页面，内容是中国城市的列表（UITableView 实现），用户可以选择切换城市。要求按拼音首字母分组（section），右侧有首字母索引，可以快速切换到以某一个字母开始的分组。从功能及页面结构上，跟微信的通讯录页及系统的通讯录页面其实是一个意思。

最开始是用系统的方式实现的，已经满足需求。但是还是仔细对比了一下微信的通讯录，发现微信做了很多的细节，是系统的通讯录里所没有实现的。本文要探究的是这些细节中的一个点的一小部分。

我们知道UITableView的style设置为UITableViewStyle.plain，其分组的头部视图（即 Section Header View）会是吸顶的效果，并且如果继续往上滑，会有下面的sectionHeader_B将原来吸在顶部的sectionHeader_A给顶出去，然后sectionHeader_B吸在顶部。仔细观察微信通讯录的细节，发现吸在顶部的ectionHeader的title的颜色是高亮的绿色，而不再顶部的颜色是灰色，并且如果发生如上面所述的顶出去的效果的过程中，两个title的颜色还会跟随着位置的改变有渐变的效果。

就是这个细节引发了我的思考，如果我们也要做这个效果，改怎么做？

解决问题的过程
又仔细查了一遍UITableView的API，可以获取到section header的是下面的几个方法：

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section NS_AVAILABLE_IOS(6_0);
- (void)tableView:(UITableView *)tableView didEndDisplayingHeaderView:(UIView *)view forSection:(NSInteger)section NS_AVAILABLE_IOS(6_0);
- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
- (nullable UITableViewHeaderFooterView *)headerViewForSection:(NSInteger)section NS_AVAILABLE_IOS(6_0);

发现苹果并没有提供相关的事件回调，说明我们要想知道相关的事件，就需要自己动手了。

Section Header在UITableView滚动时的行为
为了搞清楚这个问题，写了如下一个简单的子类

class YYHeaderView: UITableViewHeaderFooterView {
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        print("----------------------- \(String(describing: self.superview))")
    }
    
    override var frame: CGRect {
        didSet (newValue) {
            print("----------------------- \(newValue.origin)")
        }
    }
}
当装载到UITableView滚动时，发现其didMoveToSuperview时机与willDisplayHeaderView与didEndDisplayingHeaderView时机相对应，其加到UITableView上的之后就不会发生改变，没有其他的探究空间了。
但是发现其frame这个方法一直在重新赋值，分两种情况：

当没有吸顶也就是自由滚动的时候，重新赋值的frame都是一样的，这也比较容易理解，因为其随着一起滚动，而滚动是UITableView的contentOffset在改变，而SectionHeader的frame就不需要改变了。
当吸顶的时候，其frame随着滚动而发生改变，原因是contentOffset一直在改变，而SectionHeader要相对屏幕不变，其frame.origin.y就需要改变了。
将屏幕上所有的SectionHeader找出来
发现并没有跟可以返回所有可显示的cell类似的接口，只有一个接口- (nullable UITableViewHeaderFooterView *)headerViewForSection:(NSInteger)section是返回具体某个Section的Header。其实通过这个接口一个一个查也行，但是如何知道屏幕上当前显示的有哪几个section呢？

寻寻觅觅，找打一个open var indexPathsForVisibleRows: [IndexPath]? { get }接口，可以返回屏幕上所有可见的IndexPath，而IndexPath里面其实是包含section信息的，所以我们可以通过如下方法实现:

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === self.contentTableView else {
            return
        }
        let tableView = self.contentTableView
        
        guard let indexPaths = tableView.indexPathsForVisibleRows, !indexPaths.isEmpty else {
            return
        }
        
        let headers: [UITableViewHeaderFooterView] = {
            let range = indexPaths.first!.section...indexPaths.last!.section
            var headers: [UITableViewHeaderFooterView] = []
            for i in range {
                if let header = tableView.headerView(forSection: i) {
                    headers.append(header)
                }
            }
            return headers
        }()
        // 这里的headers 就是屏幕上所有的header了
    }
这里注意一点，如果某一个section下面如果有0个cell，indexPaths里就不会包含那个section的IndexPath，因为这个接口查询的是可现实的row，既cell，但是这个section及时没有一个cell，但是其Secton Header还是可以存在的（但是这个header其实没有任何存在的意义，这样的组其实应该被踢除出数据源），我们用的方法是把第一个IndexPath的section到最后一个IndexPath的section这个范围里面的所有都需要查询一下。也就是let range = indexPaths.first!.section...indexPaths.last!.section 的原因，也可以使用 map、去重、之后再排序的做法，不考虑没有意义的情况发生

        let dupSections = indexPaths.map { $0.section }
        let set = Set(dupSections)
        let sections = Array(set).sorted()
解法1.0
弄清楚了在UITableView滚动时，SectionHeader的frame的变化，以及可以找出所有的SectionHeader，结合SectionHeader在吸顶或者不吸顶时的行为，想到一个办法是拿第一个SectionHeader的frame的minY与UITableView的contentOffset的y比较，1.如果这两个值是相等的，则说明正好是在顶部的位置，是在吸顶了；2.如果小于的关系，说明在被顶出去的过程中；3.如果被顶出去了，就跟被顶出去的这个没有什么关系了，因为每次都是拿第一个找到的header来比较的；4，如果是大于的关系，说明第一个没有吸顶，应该是tableHeaderView还在展示。

有了规则其实就可以开始写代码了，但是实现之后发现，在UITableView滑动并且SectionHeader吸顶的过程中，其两个值是不相等的，并且滑动速度越快，相差越大，所以规律没办法控制，此方法失败。

但是为什么会相差呢？我只想说在scrollViewDidScroll回调的时机，contentOffset已经被设置为了将来想去的地方，而SectionHeader的frame还是当前的值，这也就解释了其差值为什么跟滑动速度有关。不过这只是我自己的猜测理解，暂时是这么理解的。

解法2.0
思路是既然SectionHeader的frame跟contentOffset设置不同步，那SectionHeader只见总应该是同步的吧，所以就想利用子视图之间的关系来做：

如果屏幕上有两个及以上的header，如果第二个header与第一个header挨着，其实是被顶出去的过程中，才会发生这种情况(不考虑某个section的cell为0)
如果不是第一种情况，那我们可以判断第一个SectionHeader下面挨着的是不是本组的第一个cell，如果紧挨着本组第一个cell，可以认为不吸顶
剩下的就是单个吸顶的情况
注意：没有考虑某个分组没有cell，也没有考虑有FooterView的情况。

代码实现：
func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === self.contentTableView else {
            return
        }
        let tableView = self.contentTableView
        
        guard let indexPaths = tableView.indexPathsForVisibleRows, !indexPaths.isEmpty else {
            return
        }
        
        let headers: [UITableViewHeaderFooterView] = {
            let range = indexPaths.first!.section...indexPaths.last!.section
            var headers: [UITableViewHeaderFooterView] = []
            for i in range {
                if let header = tableView.headerView(forSection: i) {
                    headers.append(header)
                }
            }
            return headers
        }()
        
        if headers.isEmpty {
            return
        }
        
        let firstHeader = headers.first!
        if headers.count > 1 {
            // 2个以上 看第二个跟第一个是不是挨着
            let secondHeader = headers[1]
            let delta = secondHeader.frame.minY - firstHeader.frame.maxY
            if abs(delta) <= 1 {
                // 正在交换的那个 可以给两个section 根据位置设置渐变色
                firstHeader.textLabel?.textColor = UIColor.green
                return
            }
        }
        // 不是正在交换 跟cell 比
        if let firstIndex = indexPaths.first,
            firstIndex.row == 0,
            let cell = tableView.cellForRow(at: firstIndex) {
            let delta = cell.frame.minY - firstHeader.frame.maxY
            if abs(delta) <= 1 {
                // 不吸顶 有tableHeaderView还在显示
                firstHeader.textLabel?.textColor = UIColor.gray
                return
            }
        }
        
        // 是吸顶 第一个吸顶的情况
        firstHeader.textLabel?.textColor = UIColor.red
    }
通过上述方法，还可以知道当前处于哪个section，相应的设置右侧的索引(前提是索引是自定义的，系统的不支持高亮)

链接：https://www.jianshu.com/p/d9743e751367

声明：此demo是本人根据上述链接的swift版本改造的OC版本，如有雷同，请勿见怪。
