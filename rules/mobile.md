# 移动端代码审查专项规则

## 1. iOS / Swift
- [id: mobile:ios-force-unwrap] [ ] `!` 强制解包是否安全（优先 `?` / `guard let`）？
- [id: mobile:ios-weak-self] [ ] `weak self` 是否在闭包中避免循环引用？
- [id: mobile:ios-main-queue] [ ] `DispatchQueue.main` 是否在 UI 操作时使用？
- [id: mobile:ios-userdefaults-sensitive] [ ] `UserDefaults` 是否存储敏感数据（应存 Keychain）？
- [id: mobile:ios-network-weak] [ ] 网络请求是否处理弱网/无网状态？
- [id: mobile:ios-image-cache] [ ] 图片是否用 `UIImage(named:)` 缓存（避免重复加载）？
- [id: mobile:ios-cell-reuse] [ ] `UITableView` / `UICollectionView` 是否 cell 复用？
- [id: mobile:ios-dark-mode] [ ] 是否适配 Dark Mode / Dynamic Type？
- [id: mobile:ios-background-state] [ ] App 是否处理后台状态（`applicationDidEnterBackground`）？
- [id: mobile:ios-permission] [ ] 定位/相机/麦克风权限是否提前申请？

## 2. Android / Kotlin
- [id: mobile:android-bang-abuse] [ ] `!!` 是否滥用（应用 `?.let` / `?:`）？
- [id: mobile:android-lifecycle-bind] [ ] `LifecycleObserver` 是否正确绑定（防内存泄漏）？
- [id: mobile:android-coroutine-dispatcher] [ ] `Coroutine` 是否在正确 `Dispatcher` 上（IO/Default/Main）？
- [id: mobile:android-viewbinding] [ ] `ViewBinding` 是否替代 `findViewById`？
- [id: mobile:android-viewholder-reuse] [ ] `RecyclerView` 是否 ViewHolder 复用？
- [id: mobile:android-workmanager] [ ] 后台任务是否用 `WorkManager`（非 Service）？
- [id: mobile:android-bitmap-oom] [ ] Bitmap 是否压缩/复用（防 OOM）？
- [id: mobile:android-apply-pref] [ ] `SharedPreferences` 是否 `apply()` 替代 `commit()`？
- [id: mobile:android-encrypted-pref] [ ] 敏感数据是否存 `EncryptedSharedPreferences`？
- [id: mobile:android-dpi] [ ] 是否适配不同屏幕密度（dpi）？

## 3. Flutter
- [id: mobile:flutter-setstate-minimize] [ ] `setState()` 是否最小化重建范围？
- [id: mobile:flutter-buildcontext-async] [ ] `BuildContext` 是否在 async 后使用（防 mounted 问题）？
- [id: mobile:flutter-cached-image] [ ] 图片是否用 `cached_network_image`？
- [id: mobile:flutter-futurebuilder-state] [ ] `FutureBuilder` 是否有 error/loading 状态？
- [id: mobile:flutter-platform-channel] [ ] Platform Channel 是否异常处理？
- [id: mobile:flutter-shrinkwrap] [ ] 是否避免 `shrinkWrap: true` 在大列表（用 Sliver）？
- [id: mobile:flutter-anim-dispose] [ ] 动画是否在 dispose 中清理？

## 4. React Native
- [id: mobile:rn-useeffect-cleanup] [ ] `useEffect` 是否在组件卸载时清理？
- [id: mobile:rn-flatlist-optimize] [ ] `FlatList` 是否配置 `keyExtractor` / `getItemLayout`？
- [id: mobile:rn-native-thread] [ ] 原生模块是否主线程调用（桥接性能）？
- [id: mobile:rn-hermes] [ ] Hermes 是否启用（减小包体积）？
- [id: mobile:rn-new-arch] [ ] 第三方库是否支持新架构（TurboModules/Fabric）？
- [id: mobile:rn-back-gesture] [ ] 是否处理 Android 返回键 / iOS 手势返回？

## 5. 通用移动端
- [id: mobile:offline-cache] [ ] 是否支持离线模式（本地缓存策略）？
- [id: mobile:bundle-size] [ ] 包体积是否优化（代码分割、资源压缩）？
- [id: mobile:crash-monitor] [ ] 是否接入崩溃监控（Firebase/Crashlytics/Bugly）？
- [id: mobile:startup-time] [ ] 启动时间是否优化（懒加载、预加载）？
- [id: mobile:low-memory] [ ] 是否处理低内存警告？
- [id: mobile:gesture-conflict] [ ] 手势冲突是否处理（滑动返回 vs 侧滑菜单）？
