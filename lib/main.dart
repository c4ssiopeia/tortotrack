import 'package:flutter/material.dart';
import 'src/app_colors.dart';
import 'src/table_screen.dart';
// import 'src/screen_graph.dart';
// import 'src/screen_settings.dart';


List<String> titles = <String>['List', 'Graph', 'Settings'];


void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyAppBar(),
    );
  }
}

class MyAppBar extends StatelessWidget {
  const MyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    const int tabsCount = 3;

    return DefaultTabController(
      initialIndex: 1,
      length: tabsCount,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('This is the weighttrack app.'),
          backgroundColor: AppColors.oceanBlue,
          foregroundColor: AppColors.background,
          notificationPredicate: (ScrollNotification notification) {
            return notification.depth == 1;
          },
          // The elevation value of the app bar when scroll view has
          // scrolled underneath the app bar.
          scrolledUnderElevation: 4.0,
          // shadowColor: Theme.of(context).shadowColor,
          bottom: TabBar(
            tabs: <Widget>[
              Tab(icon: const Icon(Icons.table_view_outlined, color: AppColors.background)),
              Tab(icon: const Icon(Icons.show_chart_outlined, color: AppColors.background)),
              Tab(icon: const Icon(Icons.settings_outlined, color: AppColors.background)),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            TableScreen(),
            ListView.builder(
              itemCount: 3,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  // tileColor: index.isOdd ? oddItemColor : evenItemColor,
                  title: Text('${titles[1]} $index'),
                );
              },
            ),
            ListView.builder(
              itemCount: 3,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  // tileColor: index.isOdd ? oddItemColor : evenItemColor,
                  title: Text('${titles[2]} $index'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}



