import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:cambodia_geography/app.dart';
import 'package:cambodia_geography/constants/config_constant.dart';
import 'package:cambodia_geography/exports/exports.dart';
import 'package:cambodia_geography/helpers/number_helper.dart';
import 'package:cambodia_geography/mixins/cg_theme_mixin.dart';
import 'package:cambodia_geography/models/comment/comment_list_model.dart';
import 'package:cambodia_geography/models/comment/comment_model.dart';
import 'package:cambodia_geography/models/places/place_model.dart';
import 'package:cambodia_geography/providers/user_provider.dart';
import 'package:cambodia_geography/services/apis/comment/comment_api.dart';
import 'package:cambodia_geography/services/apis/comment/crud_comment_api.dart';
import 'package:cambodia_geography/widgets/cg_bottom_nav_wrapper.dart';
import 'package:cambodia_geography/widgets/cg_custom_shimmer.dart';
import 'package:cambodia_geography/widgets/cg_load_more_list.dart';
import 'package:cambodia_geography/widgets/cg_measure_size.dart';
import 'package:cambodia_geography/widgets/cg_network_image_loader.dart';
import 'package:cambodia_geography/widgets/cg_no_data_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

class CommentScreen extends StatefulWidget {
  const CommentScreen({required this.place, Key? key}) : super(key: key);

  final PlaceModel place;

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> with CgThemeMixin {
  late CommentApi commentApi;
  late CrudCommentApi crudCommentApi;
  late TextEditingController textController;
  late ScrollController scrollController;
  CommentListModel? commentListModel;
  List<CommentModel>? comments;
  final GlobalKey<AnimatedListState> listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    textController = TextEditingController();
    scrollController = ScrollController();
    commentApi = CommentApi(id: widget.place.id ?? '');
    crudCommentApi = CrudCommentApi();
    super.initState();
    load();
  }

  @override
  void dispose() {
    scrollController.dispose();
    textController.dispose();
    super.dispose();
  }

  Future<void> load({bool loadMore = false}) async {
    if (loadMore && !(commentListModel?.hasLoadMore() == true)) return;
    String? page = commentListModel?.links?.getPageNumber().next.toString();
    final result = await commentApi.fetchAll(queryParameters: {'page': loadMore ? page : null});
    if (commentApi.success() && result != null) {
      setState(() {
        if (commentListModel != null && loadMore) {
          commentListModel?.add(result);
        } else {
          commentListModel = result;
        }
      });
    }
  }

  Future<void> createComment(String commentMsg) async {
    if (widget.place.id == null) return;
    if (commentMsg.length == 0) return;
    FocusScope.of(context).unfocus();
    App.of(context)?.showLoading();
    await crudCommentApi.createComment(
      placeId: widget.place.id!,
      comment: commentMsg,
    );
    if (crudCommentApi.success()) {
      await load();
      scrollController.animateTo(0, duration: ConfigConstant.duration, curve: Curves.ease);
      App.of(context)?.hideLoading();
    } else
      showOkAlertDialog(context: context, title: 'Comment failed');
    textController.clear();
  }

  Future<void> onTapCommentOption(CommentModel? comment) async {
    var userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user?.id == null || comment?.user?.id == null) return;
    if (comment?.user?.id == userProvider.user!.id) {
      var option = await showModalActionSheet<String>(
        context: context,
        actions: [
          SheetAction(label: 'Edit', key: 'edit'),
          SheetAction(
            label: 'Delete',
            key: 'delete',
            isDestructiveAction: true,
          ),
        ],
      );
      if (option == 'delete') {
        OkCancelResult result = await showOkCancelAlertDialog(
          context: context,
          title: 'Delete comment',
          isDestructiveAction: true,
          okLabel: 'Delete',
        );
        if (comment?.id == null) return;
        if (result == OkCancelResult.ok) {
          App.of(context)?.showLoading();
          await crudCommentApi.deleteComment(id: comment!.id.toString());
          if (crudCommentApi.success()) {
            await load();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Comment deleted'),
              ),
            );
            App.of(context)?.hideLoading();
          } else
            showOkAlertDialog(context: context, title: 'Comment failed');
        }
      } else {
        var commentUpdate = await showTextInputDialog(
          context: context,
          title: 'Edit comment',
          textFields: [
            DialogTextField(
              initialText: comment?.comment.toString(),
              maxLines: 10,
              minLines: 1,
            ),
          ],
        );
        if (commentUpdate == null || comment?.id == null) return;
        App.of(context)?.showLoading();
        await crudCommentApi.updateComment(id: comment!.id!, comment: commentUpdate.first);
        if (crudCommentApi.success()) {
          await load();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Comment updated'),
            ),
          );
        } else {
          await showOkAlertDialog(
            context: context,
            title: 'Comment failed',
            message: crudCommentApi.message(),
          );
        }
        App.of(context)?.hideLoading();
      }
    } else
      await showModalActionSheet(
        context: context,
        actions: [
          SheetAction(
            label: 'Report',
            isDestructiveAction: true,
          ),
        ],
      );
  }

  @override
  Widget build(BuildContext context) {
    comments = commentListModel?.items;
    return Scaffold(
      appBar: buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: () => load(),
        child: CgNoDataWrapper(
          isNoData: comments?.isEmpty == true,
          child: CgLoadMoreList(
            onEndScroll: () => load(loadMore: true),
            child: CgMeasureSize(
              onChange: (size) {
                if (size.height < MediaQuery.of(context).size.height) load(loadMore: true);
              },
              child: ListView.builder(
                key: listKey,
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                controller: scrollController,
                itemCount: comments?.length ?? 10,
                itemBuilder: (context, index) {
                  if (comments?.length == index) {
                    return Visibility(
                      key: Key('$index'),
                      visible: commentListModel?.hasLoadMore() == true,
                      child: Container(
                        alignment: Alignment.center,
                        padding: ConfigConstant.layoutPadding,
                        child: const CircularProgressIndicator(),
                      ),
                    );
                  }
                  return buildComment(
                    comment: comments?[index],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: CgBottomNavWrapper(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(ConfigConstant.objectHeight1),
                  child: Container(
                    color: colorScheme.background,
                    child: Consumer<UserProvider>(
                      builder: (context, provider, child) {
                        return CgNetworkImageLoader(
                          imageUrl: provider.user?.profileImg?.url,
                          width: ConfigConstant.objectHeight1,
                          height: ConfigConstant.objectHeight1,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
                title: TextField(
                  controller: textController,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'មតិយោបល់របស់អ្នក...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (comment) {
                    createComment(comment);
                  },
                ),
              ),
            ),
            IconButton(
              onPressed: () async {
                await createComment(textController.text);
              },
              icon: Icon(
                Icons.send,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildComment({
    required CommentModel? comment,
  }) {
    String date = comment?.createdAt != null ? DateFormat('dd MMM, yyyy, hh:mm a').format(comment!.createdAt!) : "";
    return Column(
      children: [
        ListTile(
          onLongPress: () => onTapCommentOption(comment),
          tileColor: colorScheme.surface,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(ConfigConstant.objectHeight1),
            child: Container(
              color: colorScheme.background,
              child: CgNetworkImageLoader(
                imageUrl: comment?.user?.profileImg?.url,
                width: ConfigConstant.objectHeight1,
                height: ConfigConstant.objectHeight1,
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: AnimatedCrossFade(
            duration: ConfigConstant.fadeDuration,
            crossFadeState: comment != null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Text(
              comment?.user?.username != null
                  ? (comment?.user?.username.toString() ?? '') + ' • ' + date
                  : "CamGeo's User" + ' • ' + date,
              style: textTheme.caption,
            ),
            secondChild: CgCustomShimmer(
              child: Row(
                children: [
                  Container(
                    height: 12,
                    width: 100,
                    color: colorScheme.surface,
                  ),
                ],
              ),
            ),
          ),
          subtitle: AnimatedCrossFade(
            duration: ConfigConstant.fadeDuration,
            crossFadeState: comment?.comment != null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Text(
              comment?.comment ?? '',
              style: textTheme.bodyText2,
            ),
            secondChild: CgCustomShimmer(
              child: Row(
                children: [
                  Container(
                    height: 12,
                    width: 48,
                    color: colorScheme.surface,
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 0),
      ],
    );
  }

  MorphingAppBar buildAppBar(BuildContext context) {
    return MorphingAppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0.5,
      automaticallyImplyLeading: false,
      title: RichText(
        text: TextSpan(
          text: 'មតិយោបល់ ',
          style: textTheme.bodyText1,
          children: [
            TextSpan(
              text: '• ' + NumberHelper.toKhmer(widget.place.commentLength),
              style: TextStyle(
                color: textTheme.caption?.color,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.close,
            color: colorScheme.primary,
          ),
        )
      ],
    );
  }
}
