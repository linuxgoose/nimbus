import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:isar_community/isar.dart';
import 'package:nimbus/app/api/api.dart';
import 'package:nimbus/app/api/city_api.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/ui/places/view/place_list.dart';
import 'package:nimbus/app/ui/places/widgets/place_action.dart';
import 'package:nimbus/app/ui/geolocation.dart';
import 'package:nimbus/app/ui/main/view/main_page.dart';
import 'package:nimbus/app/ui/map/view/map.dart';
import 'package:nimbus/app/ui/settings/view/settings.dart';
import 'package:nimbus/app/utils/show_snack_bar.dart';
import 'package:nimbus/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int tabIndex = 0;
  bool visible = false;
  final _focusNode = FocusNode();
  late TabController tabController;
  final weatherController = Get.put(WeatherController());
  final _controller = TextEditingController();

  final List<Widget> pages = [
    const MainPage(),
    const PlaceList(),
    if (!settings.hideMap) const MapPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    getData();
    setupTabController();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  void setupTabController() {
    tabController = TabController(
      initialIndex: tabIndex,
      length: pages.length,
      vsync: this,
    );

    tabController.animation?.addListener(() {
      int value = (tabController.animation!.value).round();
      if (value != tabIndex) setState(() => tabIndex = value);
    });

    tabController.addListener(
      () => setState(() => tabIndex = tabController.index),
    );
  }

  void getData() async {
    await weatherController.deleteCache();
    await weatherController.updateCacheCard(false);
    await weatherController.setLocation();
  }

  void changeTabIndex(int index) {
    setState(() => tabIndex = index);
    tabController.animateTo(tabIndex);
  }

  Widget _buildAppBarTitle(
    int tabIndex,
    TextStyle? textStyle,
    TextStyle? labelLarge,
  ) {
    switch (tabIndex) {
      case 0:
        return visible
            ? _buildSearchField(labelLarge)
            : Obx(() {
                final location = weatherController.location;
                // Add fallbacks to empty strings to prevent null pointer exceptions
                final city = location.city ?? '';
                final district = location.district ?? '';

                return Text(
                  weatherController.isLoading.isFalse
                      ? district.isEmpty
                            ? city
                            : city.isEmpty
                            ? district
                            : city == district
                            ? city
                            : '$city, $district'
                      : settings.location
                      ? 'search'.tr
                      : (isar.locationCaches.where().findAllSync()).isNotEmpty
                      ? 'loading'.tr
                      : 'searchCity'.tr,
                  style: textStyle,
                );
              });
      case 1:
        return Text('cities'.tr, style: textStyle);
      case 2:
        return settings.hideMap
            ? Text('settings_full'.tr, style: textStyle)
            : Text('map'.tr, style: textStyle);
      case 3:
        return Text('settings_full'.tr, style: textStyle);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSearchField(TextStyle? labelLarge) => RawAutocomplete<Result>(
    focusNode: _focusNode,
    textEditingController: _controller,
    fieldViewBuilder: (_, _, _, _) => TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: labelLarge?.copyWith(fontSize: 16),
      decoration: InputDecoration(hintText: 'search'.tr),
    ),
    optionsBuilder: (TextEditingValue textEditingValue) {
      if (textEditingValue.text.isEmpty) {
        return const Iterable<Result>.empty();
      }
      return WeatherAPI().getCity(textEditingValue.text, locale);
    },
    onSelected: (Result selection) async {
      await weatherController.deleteAll(true);
      await weatherController.getLocation(
        double.parse('${selection.latitude}'),
        double.parse('${selection.longitude}'),
        selection.admin1,
        selection.name,
      );
      visible = false;
      _controller.clear();
      _focusNode.unfocus();
      setState(() {});
    },
    displayStringForOption: (Result option) =>
        '${option.name}, ${option.admin1}',
    optionsViewBuilder:
        (
          BuildContext context,
          AutocompleteOnSelected<Result> onSelected,
          Iterable<Result> options,
        ) => _buildOptionsView(context, onSelected, options, labelLarge),
  );

  Widget _buildOptionsView(
    BuildContext context,
    AutocompleteOnSelected<Result> onSelected,
    Iterable<Result> options,
    TextStyle? labelLarge,
  ) => Align(
    alignment: Alignment.topLeft,
    child: Material(
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: SizedBox(
        width: 250,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: options.length,
          itemBuilder: (BuildContext context, int index) {
            final Result option = options.elementAt(index);
            return InkWell(
              onTap: () => onSelected(option),
              child: ListTile(
                title: Text(
                  '${option.name}, ${option.admin1}',
                  style: labelLarge,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _buildSearchIconButton() => IconButton(
    onPressed: () {
      if (visible) {
        _controller.clear();
        _focusNode.unfocus();
        visible = false;
      } else {
        visible = true;
      }
      setState(() {});
    },
    icon: Icon(visible ? LucideIcons.circleX : LucideIcons.search, size: 18),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: pages.length,
    child: ScaffoldMessenger(
      key: globalKey,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: tabIndex == 0
              ? IconButton(
                  onPressed: () => Get.to(
                    () => const SelectGeolocation(isStart: false),
                    transition: Transition.downToUp,
                  ),
                  icon: const Icon(LucideIcons.mapPlus, size: 18),
                )
              : null,
          title: _buildAppBarTitle(
            tabIndex,
            context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
            context.textTheme.labelLarge,
          ),
          actions: tabIndex == 0 ? [_buildSearchIconButton()] : null,
        ),
        body: SafeArea(
          child: TabBarView(controller: tabController, children: pages),
        ),
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: (int index) => changeTabIndex(index),
          selectedIndex: tabIndex,
          destinations: [
            NavigationDestination(
              icon: const Icon(LucideIcons.cloudSun),
              selectedIcon: const Icon(LucideIcons.cloudSun),
              label: 'name'.tr,
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.mapPinned),
              selectedIcon: const Icon(LucideIcons.mapPinned),
              label: 'cities'.tr,
            ),
            if (!settings.hideMap)
              NavigationDestination(
                icon: const Icon(LucideIcons.map),
                selectedIcon: const Icon(LucideIcons.map),
                label: 'map'.tr,
              ),
            NavigationDestination(
              icon: const Icon(LucideIcons.settings),
              selectedIcon: const Icon(LucideIcons.settings),
              label: 'settings_full'.tr,
            ),
          ],
        ),
        floatingActionButton: tabIndex == 1
            ? FloatingActionButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  enableDrag: false,
                  builder: (BuildContext context) =>
                      const PlaceAction(edit: false),
                ),
                child: const Icon(LucideIcons.plus),
              )
            : null,
      ),
    ),
  );
}
