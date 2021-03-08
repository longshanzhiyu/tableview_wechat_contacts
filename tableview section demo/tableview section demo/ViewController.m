//
//  ViewController.m
//  tableview section demo
//
//  Created by njw on 2021/3/2.
//

#import "ViewController.h"

@interface ViewController () <UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate>
@property (nonatomic, strong) UITableView *tableview;
@property (nonatomic, assign) NSInteger topSection;
@property (nonatomic, assign) BOOL isFirst;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.topSection = 0;
    [self.view addSubview:self.tableview];
    self.isFirst = YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 5;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UITableViewHeaderFooterView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"header"];
    if (nil == headerView) {
        headerView = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:@"header"];
    }
    headerView.textLabel.text = [NSString stringWithFormat:@"%ld", section];
    
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 30;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    cell.textLabel.text = [NSString stringWithFormat:@"section：%ld row：%ld", (long)indexPath.section, indexPath.row];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableview) {
        NSMutableArray *indexPaths = [[NSMutableArray alloc] initWithArray:[self.tableview indexPathsForVisibleRows]];
        NSIndexPath *fir = indexPaths.firstObject;
        if (indexPaths.count > 1) {
            for (int i=1; i<indexPaths.count; i++) {
                NSIndexPath *cur = [indexPaths objectAtIndex:i];
                if (cur.section == fir.section) {
                    [indexPaths removeObject:cur];
                }
                else {
                    fir = cur;
                }
            }
        }
        if (indexPaths.count == 0) {
            return;
        }
        NSMutableArray *tempArray = [NSMutableArray new];
        for (NSIndexPath *indexPath in indexPaths) {
            id object = [self.tableview headerViewForSection:indexPath.section];
            if (object && ![tempArray containsObject:object]) {
                [tempArray addObject:object];
            }
        }
        if (tempArray.count == 0) {
            return;
        }
        UITableViewHeaderFooterView *firstHeader = (UITableViewHeaderFooterView *)[tempArray firstObject];
        if (tempArray.count > 1) {
            UITableViewHeaderFooterView *secondHeader = [tempArray objectAtIndex:1];
            CGFloat delta = CGRectGetMinY(secondHeader.frame) - CGRectGetMaxY(firstHeader.frame);
            if (fabs(delta) <= 1) {
                
                for (UITableViewHeaderFooterView *headerView in tempArray) {
                    if ([headerView isEqual:firstHeader]) {
                        headerView.textLabel.textColor = [UIColor redColor];
                    }
                    else {
                        headerView.textLabel.textColor = [UIColor grayColor];
                    }
                }
                return;
            }
        }

        NSIndexPath *firstIndex = [indexPaths firstObject];
        if (firstIndex.row == 0) {
            UITableViewCell *cell = [self.tableview cellForRowAtIndexPath:firstIndex];
            CGFloat delta = CGRectGetMinY(cell.frame) - CGRectGetMaxY(firstHeader.frame);
            if (fabs(delta) <= 1) {
                // 不吸顶 有tableHeaderView还在显示
                firstHeader.textLabel.textColor = [UIColor grayColor];
                return;
            }
        }


                // 是吸顶 第一个吸顶的情况
        for (UITableViewHeaderFooterView *headerView in tempArray) {
            if ([headerView isEqual:firstHeader]) {
                headerView.textLabel.textColor = [UIColor redColor];
            }
            else {
                headerView.textLabel.textColor = [UIColor grayColor];
            }
        }
    }
}

- (UITableView *)tableview {
    if (nil==_tableview) {
        _tableview = [[UITableView alloc] initWithFrame:CGRectMake(0, 20, self.view.frame.size.width, self.view.frame.size.height) style:UITableViewStylePlain];
        _tableview.delegate = self;
        _tableview.dataSource = self;
    }
    return _tableview;
}

@end
