import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'package:grestapp_homeal_app/utils/services/permission_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_gen/gen_l10n/translate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grestapp_homeal_app/constants/constants.dart';
import 'package:grestapp_homeal_app/utils/helpers/misc_helper.dart';
import 'package:grestapp_homeal_app/utils/services/navigator_service.dart';
import 'package:grestapp_homeal_app/utils/style/colors.dart';
import 'package:provider/provider.dart';

import 'package:grestapp_homeal_app/providers/listings_provider.dart';
import 'package:grestapp_homeal_app/utils/helpers/map_helper.dart';
import 'package:grestapp_homeal_app/widgets/property_display_map.dart';
import 'package:grestapp_homeal_app/utils/my-libraries/simplify_polygon.dart';
import 'package:grestapp_homeal_app/widgets/filter_screen.dart';

GlobalKey<ScaffoldState> scaff = GlobalKey<ScaffoldState>();

class MapViewer extends StatefulWidget {
  final FromPage fromPage;

  const MapViewer({Key? key, required this.fromPage}) : super(key: key);

  @override
  State<MapViewer> createState() => _MapViewerState();
}

class _MapViewerState extends State<MapViewer> {
  /// Set of displayed markers and cluster markers on the map
  Set<Marker> _markers = {};
  bool _mapVisible = true;

  /// Url image used on normal markers
  final String _markerImageUrl = 'https://cdn-icons-png.flaticon.com/512/3477/3477419.png';

  /// Color of the cluster circle
  final Color _clusterColor = Platform.isAndroid ? const Color(0xFF1c0162) : CustomColors.navSelected;

  /// Color of the cluster text
  final Color _clusterTextColor = Colors.white;

  /// Example marker coordinates
  final List<LatLng> _markerLocations = [];
  List<int> indexes = [];

  bool _isLoading = true;
  final bool _isLoading2 = false;

  /// Markers loading flag
  final bool _areMarkersLoading = true;

  bool _drawCircleEnabled = false;

  double getZoomLevel(double radius) {
    double zoomLevel = 11;
    if (radius > 0) {
      double radiusElevated = radius + radius / 2;
      double scale = radiusElevated / 500;
      zoomLevel = 16 - math.log(scale) / math.log(2);
    }

    return zoomLevel;
  }

  double radius = 1000;
  bool flagNegra = false;
  LatLng center = const LatLng(0, 0);
  Set<Circle> s = {};

  bool toggleDrawingCircle = false;
  bool isUpdating = false;

  @override
  void dispose() {
    _googleMapController!.dispose();
    super.dispose();
  }

  Future<void> initAll() async {
    if (!mounted) {
      return; // Check if the widget is unmounted and return early.
    }

    try {
      await context.read<ListingsProvider>().getSearchedListingsMap(context);

      if (widget.fromPage == FromPage.exploreProperties) {
        for (int i = 0; i < context.read<ListingsProvider>().listingsFromServerMap.length; i++) {
          _markerLocations.add(context.read<ListingsProvider>().listingsFromServerMap[i].coordinate);
          indexes.add(i);
        }
      } else {
        throw Exception("");
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      final value = await _googleMapController!.getVisibleRegion();
      final zoomLevel = await _googleMapController!.getZoomLevel();
      await _updateMarkers(value, zoomLevel);
    } catch (e) {
      // Handle any exceptions that may occur during the above operations.
    }
  }

  late Brightness currentBrightness;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration.zero, () async {
        await initAll();
        await PermissionService.location();
        if (mounted) {
          setState(() {});
        }
      });
    });
    _drawPolygonEnabled = false;
    _userPolyLinesLatLngList = [];
    _clearDrawing = false;

    currentBrightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
  }

  /// Inits [Fluster] and all the markers with network images and updates the loading state.
  Future<void> _initMarkers({double? zoom}) async {
    if (mounted) {
      setState(() {
        _drawCircleEnabled = false;
        _drawPolygonEnabled = false;
      });
    }
    final List<Marker> markers = [];
    int limitMarkers = 100;

    if (zoom != null && zoom < 7) limitMarkers = 100;

    const double initialRadius = 10.0;
    const double maxRadius = 10.0;
    double adjustedRadius = 10;

    // Calculate the adjusted radius based on the zoom level
    adjustedRadius = initialRadius + (1 / zoom!) * 100.0

      // Ensure the adjusted radius does not exceed the maximum radius
      ..clamp(0.0, maxRadius);
    var listingsProvider;
    if (mounted) listingsProvider = context.read<ListingsProvider>();
    final currencyFormatter = NumberFormat.compactCurrency(decimalDigits: 0, symbol: '');

    final List<PropertyDisplayMap> propertyDisplayMaps = List.generate(_markerLocations.length, (i) {
      final listing = listingsProvider.listingsFromServerMap[i];
      return PropertyDisplayMap(
        listingID: listing.id,
        category: listing.category,
        // Add any other necessary properties
      );
    });

    Future<void> handleMarkerTap(int index) async {
      if (!_drawCircleEnabled && !_drawPolygonEnabled) {
        await showModalBottomSheet(
          barrierColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          context: context,
          isScrollControlled: true,
          builder: (context) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.only(bottom: 25, left: 15, right: 15),
              child: propertyDisplayMaps[index],
            );
          },
        );
      }
    }

    for (int i = 0; i < _markerLocations.length; i++) {
      final listing = listingsProvider.listingsFromServerMap[i];

      final icon = await (zoom < 13
          ? MapHelper.createCircularBitmapDescriptor(
              CustomColors.btnBgRed, // Fill color
              adjustedRadius, // Radius
              Colors.white, // Border color
              5, // Border width
            )
          : MapHelper.createCustomMarkerBitmap(
              currencyFormatter.format(double.parse(listing.price.replaceAll(",", "").replaceAll("€", ""))),
              listing.type.name,
              textStyle: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700),
            ));

      markers.add(
        Marker(
          onTap: () => handleMarkerTap(i),
          markerId: MarkerId(_markerLocations.indexOf(_markerLocations[i]).toString()),
          position: _markerLocations[i],
          icon: icon,
        ),
      );
    }
    if (mounted) {
      setState(() {
        _markers = markers.toSet();
      });
    }
/*
    _clusterManager = await MapHelper.initClusterManager(
      markers,
      _minClusterZoom,
      _maxClusterZoom,
    );
    await _updateMarkers();*/
  }

  /// Gets the markers and clusters to be displayed on the map for the current zoom level and
  /// updates state.
  Future<void> _updateMarkers(LatLngBounds bounds, [double? updatedZoom]) async {
    final List<Marker> markers = [];
    int limitMarkers = 100;

    if (updatedZoom != null && updatedZoom < 7) limitMarkers = 100;
    if (!isUpdating) {
      if (mounted) {
        setState(() {
          isUpdating = true;
        });
      }

      // Define the initial circle radius and the desired maximum circle radius
      const double initialRadius = 10.0;
      const double maxRadius = 10.0;
      double adjustedRadius = 10;
      if (updatedZoom != null) {
        // Calculate the adjusted radius based on the zoom level
        adjustedRadius = initialRadius + (1 / updatedZoom) * 100.0;

        // Ensure the adjusted radius does not exceed the maximum radius
        adjustedRadius.clamp(0.0, maxRadius);
      }
      int counter = 0;
      for (int i = 0; i < _markerLocations.length; i++) {
        if (_markerLocations[i].latitude < bounds.northeast.latitude &&
            _markerLocations[i].longitude < bounds.northeast.longitude &&
            _markerLocations[i].latitude > bounds.southwest.latitude &&
            _markerLocations[i].longitude > bounds.southwest.longitude) {
          counter++;

          markers.add(
            Marker(
              onTap: () {
                if (!_drawCircleEnabled && !_drawPolygonEnabled) {
                  showModalBottomSheet(
                    barrierColor: Colors.transparent,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    context: context,
                    isScrollControlled: true,
                    builder: (context) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.only(bottom: 25, left: 15, right: 15),
                        child: PropertyDisplayMap(
                          listingID: context.read<ListingsProvider>().listingsFromServerMap[i].id,
                          category: context.read<ListingsProvider>().listingsFromServerMap[i].category,
                        ),
                      );
                    },
                  );
                }
              },
              markerId: MarkerId(_markerLocations.indexOf(_markerLocations[i]).toString()),
              position: _markerLocations[i],
              icon: (updatedZoom != null && updatedZoom < 13)
                  ? await MapHelper.createCircularBitmapDescriptor(
                      CustomColors.btnBgRed, // Fill color
                      adjustedRadius, // Radius
                      Colors.white, // Border color
                      5, // Border width
                    )
                  : await MapHelper.createCustomMarkerBitmap(
                      NumberFormat.compactCurrency(
                        decimalDigits: 0,
                        symbol: '', // if you want to add currency symbol then pass that in this else leave it empty.
                      ).format(
                        double.parse(
                          context.read<ListingsProvider>().listingsFromServerMap[i].price.replaceAll(",", "").replaceAll("€", ""),
                        ),
                      ),
                      context.read<ListingsProvider>().listingsFromServerMap[i].type.name,
                      textStyle: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700),
                    ),
            ),
          );
          if (counter > limitMarkers) break;
        }
      }
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
    if (mounted) {
      setState(() {
        _markers = markers.toSet();
      });
    }
  }

  final Set<Polygon> _polygons = HashSet<Polygon>();
  final Set<Polyline> _polyLines = HashSet<Polyline>();
  bool _drawPolygonEnabled = false;
  List<LatLng> _userPolyLinesLatLngList = [];
  bool _clearDrawing = false;
  int? _lastXCoordinate, _lastYCoordinate;
  String polygon = "";

  String tmp = "";
  late LatLng initialPosition = const LatLng(41.327953, 19.819025);
  GoogleMapController? _googleMapController;
  Map filters = {};

  Future<void> getFiltersValueCallback() async {
    if (mounted) {
      setState(() {
        context.read<ListingsProvider>().searchedListings.filtersV2.currentLocation = tmp;
        _drawPolygonEnabled = false;
        _drawCircleEnabled = false;
        _isLoading = true;
        visible = false;
        visible1 = false;
      });
    }

    context.read<ListingsProvider>().searchedListings.filtersV2.suggestedLocation = null;
    context.read<ListingsProvider>().searchedListings.filtersV2.administrativeDivisions = null;

    _markerLocations.clear();
    indexes.clear();

    await initAll();
    if (toggleDrawingCircle) {
      _toggleDrawingCircle();
      toggleDrawingCircle = false;
    } else {
      _toggleDrawing();
    }
    await _initMarkers(zoom: await _googleMapController!.getZoomLevel());

    if (mounted) {
      setState(() {
        _isLoading = false;
        //if (_markerLocations.length == 0) SnackBarService("Nessun annuncio trovato", "info", context);
      });
    }
    await context.read<ListingsProvider>().getSearchedListings(context); //await ?
  }

  bool visible = false;
  bool visible1 = false;

  bool type = true;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (value) async {
        if (value) {
          setState(() {
            _mapVisible = false;
          });
        }
      },
      child: ScaffoldMessenger(
        child: Scaffold(
          bottomNavigationBar: (visible1)
              ? SafeArea(
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    height: 100,
                    color: isDark(context) ? CustomColors.bg2Dark : CustomColors.bg2,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child:
                              Text('${(radius < 1000) ? ((radius / 1000).toStringAsFixed(2)) : ((radius / 1000).toStringAsFixed(0))} Km'),
                        ),
                        Slider(
                          activeColor: isDark(context) ? CustomColors.navSelectedDark : CustomColors.navSelected,
                          max: 50000,
                          min: 200,
                          divisions: 50,
                          onChanged: (double values) async {
                            if (mounted) {
                              setState(() {
                                radius = values;

                                s.clear();
                                Circle circle = Circle(
                                  circleId: const CircleId("1"),
                                  strokeWidth: 5,
                                  center: center,
                                  radius: radius,
                                  strokeColor: isDark(context) ? CustomColors.navSelectedDark : CustomColors.navSelected,
                                  fillColor:
                                      isDark(context) ? const Color.fromARGB(23, 147, 136, 205) : const Color.fromARGB(40, 100, 80, 170),
                                );
                                s.add(circle);
                              });
                            }

                            await _googleMapController!.animateCamera(CameraUpdate.zoomTo(getZoomLevel(radius)));
                          },
                          value: radius,
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          body: Stack(
            alignment: Alignment.topCenter,
            children: [
              GestureDetector(
                onPanUpdate: (_drawPolygonEnabled) ? _onPanUpdate : null,
                onPanEnd: (_drawPolygonEnabled) ? _onPanEnd : null,
                child: _mapVisible
                    ? GoogleMap(
                        style: isDark(context) ? MapStyle.mapStyle : null,
                        rotateGesturesEnabled: !_drawCircleEnabled && !_drawPolygonEnabled,
                        zoomGesturesEnabled: !_drawCircleEnabled && !_drawPolygonEnabled,
                        zoomControlsEnabled: !_drawCircleEnabled && !_drawPolygonEnabled,
                        tiltGesturesEnabled: !_drawCircleEnabled && !_drawPolygonEnabled,
                        onTap: (argument) {
                          if (_drawCircleEnabled && !visible1) {
                            center = LatLng(argument.latitude, argument.longitude);
                            if (mounted) {
                              setState(() {
                                visible1 = true;
                                Circle circle = Circle(
                                  circleId: const CircleId("1"),
                                  strokeWidth: 5,
                                  center: center,
                                  radius: radius,
                                  strokeColor: isDark(context) ? CustomColors.navSelectedDark : CustomColors.navSelected,
                                  fillColor:
                                      isDark(context) ? const Color.fromARGB(23, 147, 136, 205) : const Color.fromARGB(40, 100, 80, 170),
                                );
                                s.add(circle);
                                _googleMapController!.animateCamera(CameraUpdate.newLatLng(center));
                              });
                            }
                          }
                        },
                        circles: _drawCircleEnabled ? s : {},
                        polygons: _polygons,
                        polylines: _polyLines,
                        key: scaff,
                        markers: _markers,
                        mapType: type ? MapType.normal : MapType.hybrid,
                        myLocationButtonEnabled: false,
                        initialCameraPosition: CameraPosition(
                          target: initialPosition,
                          zoom: 10,
                        ),
                        onCameraIdle: () async {
                          if (_googleMapController != null) {
                            await _googleMapController!
                                .getVisibleRegion()
                                .then((value) async => _updateMarkers(value, await _googleMapController!.getZoomLevel()));
                          }
                        },
                        onMapCreated: (GoogleMapController controller) {
                          _googleMapController = controller;
                        },
                      )
                    : Container(),
              ),
              if (_isLoading2)
                SafeArea(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isDark(context) ? const Color.fromARGB(255, 226, 226, 226) : const Color(0xFF505050),
                    ),
                    child: Text(
                      Translate.of(context).noListingsFound,
                      style: TextStyle(color: isDark(context) ? Colors.black : Colors.white),
                    ),
                  ),
                ),
              if (_isLoading)
                SafeArea(
                  child: Container(
                    margin: const EdgeInsets.only(top: 25),
                    decoration: BoxDecoration(
                      color: Platform.isAndroid
                          ? isDark(context)
                              ? const Color(0xFF4e3697)
                              : Colors.white
                          : isDark(context)
                              ? CustomColors.navSelectedDark2
                              : const Color.fromARGB(255, 255, 255, 255),
                      borderRadius: const BorderRadius.all(Radius.circular(500)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Platform.isAndroid
                            ? isDark(context)
                                ? const Color(0xFFcfbcff)
                                : const Color(0xFF1c015d)
                            : isDark(context)
                                ? CustomColors.navSelectedDark
                                : CustomColors.navSelected,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              if (visible1)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 100,
                    child: FloatingActionButton(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      heroTag: 1,
                      backgroundColor: CustomColors.btnBgRed,
                      onPressed: () async {
                        toggleDrawingCircle = true;

                        context.read<ListingsProvider>().searchedListings.filtersV2.setDistanceFromPoint(center, radius);
                        tmp = "distance_from_point";

                        await showModalBottomSheet(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          context: context,
                          isScrollControlled: true,
                          builder: (context) {
                            return FractionallySizedBox(
                              heightFactor: 0.92,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: CustomColors.bg2,
                                ),
                                child: FilterScreen(
                                  getFiltersValueCallback: getFiltersValueCallback,
                                  fromPage: FromPage.map,
                                  radius: radius,
                                  radiusPoint: center,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      child: Text(
                        Translate.of(context).selectOnly,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                )
              else if (visible)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      width: 100,
                      child: FloatingActionButton(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        heroTag: 2,
                        backgroundColor: CustomColors.btnBgRed,
                        onPressed: () async {
                          List<math.Point> pts = _userPolyLinesLatLngList.map((LatLng i) => math.Point(i.longitude, i.latitude)).toList();

                          double tolerance = 0.00001;

                          while (pts.length > 50) {
                            List<math.Point> simplifiedPts = simplifyPolygon(pts, highestQuality: true, tolerance: tolerance);
                            if (simplifiedPts.length <= 50) {
                              pts = simplifiedPts;
                              break;
                            }
                            tolerance *= 1.2;
                          }

                          math.Point firstPoint = pts.first;
                          List<math.Point> uniquePoints = List<math.Point>.from(pts.skip(1).toSet())
                            ..removeWhere((point) => point == firstPoint)
                            ..insert(0, firstPoint)
                            ..add(firstPoint);

                          String polygonTmp = "";
                          for (int i = 0; i < uniquePoints.length; i++) {
                            if (i == uniquePoints.length - 1) {
                              polygonTmp += "${uniquePoints[i].x.toStringAsFixed(6)} ${uniquePoints[i].y.toStringAsFixed(6)}";
                            } else {
                              polygonTmp += "${uniquePoints[i].x.toStringAsFixed(6)} ${uniquePoints[i].y.toStringAsFixed(6)},";
                            }
                          }

                          context.read<ListingsProvider>().searchedListings.filtersV2.setPolygon(polygonTmp);

                          tmp = "hand_drawing";

                          //flutterLog(polygonTmp, color: "red");

                          await showModalBottomSheet(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            context: context,
                            isScrollControlled: true,
                            builder: (context) {
                              return FractionallySizedBox(
                                heightFactor: 0.92,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: CustomColors.bg2,
                                  ),
                                  child: FilterScreen(
                                    getFiltersValueCallback: getFiltersValueCallback,
                                    fromPage: FromPage.map,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        child: Text(
                          Translate.of(context).selectOnly,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Container(
                    height: 55,
                    width: 55,
                    margin: pageMargin,
                    child: FloatingActionButton(
                      heroTag: 3,
                      backgroundColor: Platform.isAndroid
                          ? isDark(context)
                              ? const Color(0xFF4e3697)
                              : Colors.white
                          : isDark(context)
                              ? CustomColors.navSelectedDark2
                              : const Color.fromARGB(255, 255, 255, 255),
                      onPressed: () async {
                        setState(() {
                          _mapVisible = false;
                        });

                        NavigatorService.pop(context);
                      },
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: Platform.isAndroid
                            ? isDark(context)
                                ? const Color(0xFFcfbcff)
                                : const Color(0xFF1c015d)
                            : isDark(context)
                                ? CustomColors.navSelectedDark
                                : CustomColors.navSelected,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: SafeArea(
            child: Container(
              margin: pageMargin,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (context.read<ListingsProvider>().searchedListings.filtersV2.currentLocation == "distance_from_point" ||
                            context.read<ListingsProvider>().searchedListings.filtersV2.currentLocation == "hand_drawing")
                          SizedBox(
                            height: 65,
                            width: 65,
                            child: FloatingActionButton(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              heroTag: 4,
                              backgroundColor: Platform.isAndroid
                                  ? isDark(context)
                                      ? const Color(0xFF4e3697)
                                      : Colors.white
                                  : isDark(context)
                                      ? CustomColors.navSelectedDark2
                                      : Colors.white,
                              onPressed: () async {
                                if (mounted) {
                                  setState(() {
                                    _drawCircleEnabled = false;
                                    _drawPolygonEnabled = false;
                                  });
                                }
                                context.read<ListingsProvider>().searchedListings.filtersV2.administrativeDivisions = null;
                                context.read<ListingsProvider>().searchedListings.filtersV2.suggestedLocation = null;
                                context.read<ListingsProvider>().searchedListings.filtersV2.currentLocation = "";
                                if (mounted) {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                }
                                _markerLocations.clear();
                                indexes.clear();
                                await initAll();

                                unawaited(context.read<ListingsProvider>().getSearchedListings(context));
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.clear_circled,
                                    color: isDark(context) ? CustomColors.navSelectedDark : CustomColors.navSelected,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    Translate.of(context).clear,
                                    style: TextStyle(
                                      color: Platform.isIOS
                                          ? isDark(context)
                                              ? CustomColors.navSelectedDark
                                              : CustomColors.navSelected
                                          : isDark(context)
                                              ? const Color(0xFFcfbcff)
                                              : const Color(0xFF1c015d),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 65,
                          width: 65,
                          child: FloatingActionButton(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            heroTag: 5,
                            backgroundColor: Platform.isAndroid
                                ? isDark(context)
                                    ? const Color(0xFF4e3697)
                                    : Colors.white
                                : isDark(context)
                                    ? CustomColors.navSelectedDark2
                                    : Colors.white,
                            onPressed: _drawCircleEnabled ? null : _toggleDrawing,
                            child: (_drawPolygonEnabled)
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: ImageIcon(
                                          const AssetImage("assets/icons/x.png"),
                                          size: 14,
                                          color: Platform.isAndroid
                                              ? isDark(context)
                                                  ? const Color(0xFFcfbcff)
                                                  : const Color(0xFF1c015d)
                                              : isDark(context)
                                                  ? CustomColors.navSelectedDark
                                                  : CustomColors.navSelected,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        Translate.of(context).cancel,
                                        style: TextStyle(
                                          color: Platform.isIOS
                                              ? isDark(context)
                                                  ? CustomColors.navSelectedDark
                                                  : CustomColors.navSelected
                                              : isDark(context)
                                                  ? const Color(0xFFcfbcff)
                                                  : const Color(0xFF1c015d),
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Platform.isIOS
                                            ? Icon(
                                                CupertinoIcons.hand_draw,
                                                color: isDark(context) ? CustomColors.navSelectedDark : CustomColors.navSelected,
                                              )
                                            : ImageIcon(
                                                const AssetImage("assets/icons/pencil.png"),
                                                color: isDark(context) ? const Color(0xFFcfbcff) : const Color(0xFF1c015d),
                                              ),
                                        Text(
                                          Translate.of(context).draw,
                                          style: TextStyle(
                                            color: Platform.isIOS
                                                ? isDark(context)
                                                    ? CustomColors.navSelectedDark
                                                    : CustomColors.navSelected
                                                : isDark(context)
                                                    ? const Color(0xFFcfbcff)
                                                    : const Color(0xFF1c015d),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 65,
                          width: 65,
                          child: FloatingActionButton(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            heroTag: 6,
                            backgroundColor: Platform.isAndroid
                                ? isDark(context)
                                    ? const Color(0xFF4e3697)
                                    : Colors.white
                                : isDark(context)
                                    ? CustomColors.navSelectedDark2
                                    : Colors.white,
                            onPressed: _drawPolygonEnabled ? null : _toggleDrawingCircle,
                            child: (_drawCircleEnabled)
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: ImageIcon(
                                          const AssetImage("assets/icons/x.png"),
                                          size: 14,
                                          color: Platform.isAndroid
                                              ? isDark(context)
                                                  ? const Color(0xFFcfbcff)
                                                  : const Color(0xFF1c015d)
                                              : isDark(context)
                                                  ? CustomColors.navSelectedDark
                                                  : CustomColors.navSelected,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        Translate.of(context).cancel,
                                        style: TextStyle(
                                          color: Platform.isIOS
                                              ? isDark(context)
                                                  ? CustomColors.navSelectedDark
                                                  : CustomColors.navSelected
                                              : isDark(context)
                                                  ? const Color(0xFFcfbcff)
                                                  : const Color(0xFF1c015d),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      ImageIcon(
                                        const AssetImage("assets/icons/radius.png"),
                                        color: Platform.isAndroid
                                            ? isDark(context)
                                                ? const Color(0xFFcfbcff)
                                                : const Color(0xFF1c015d)
                                            : isDark(context)
                                                ? CustomColors.navSelectedDark
                                                : CustomColors.navSelected,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        Translate.of(context).radius,
                                        style: TextStyle(
                                          color: Platform.isIOS
                                              ? isDark(context)
                                                  ? CustomColors.navSelectedDark
                                                  : CustomColors.navSelected
                                              : isDark(context)
                                                  ? const Color(0xFFcfbcff)
                                                  : const Color(0xFF1c015d),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 65,
                          width: 65,
                          child: FloatingActionButton(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            heroTag: 7,
                            backgroundColor: Platform.isAndroid
                                ? isDark(context)
                                    ? const Color(0xFF4e3697)
                                    : Colors.white
                                : isDark(context)
                                    ? CustomColors.navSelectedDark2
                                    : Colors.white,
                            onPressed: () {
                              if (mounted) {
                                setState(() {
                                  type = !type;
                                });
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Platform.isIOS ? CupertinoIcons.map : Icons.map,
                                  color: Platform.isAndroid
                                      ? isDark(context)
                                          ? const Color(0xFFcfbcff)
                                          : const Color(0xFF1c015d)
                                      : isDark(context)
                                          ? CustomColors.navSelectedDark
                                          : CustomColors.navSelected,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  Translate.of(context).typeOnly,
                                  style: TextStyle(
                                    color: Platform.isIOS
                                        ? isDark(context)
                                            ? CustomColors.navSelectedDark
                                            : CustomColors.navSelected
                                        : isDark(context)
                                            ? const Color(0xFFcfbcff)
                                            : const Color(0xFF1c015d),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        /*const SizedBox(height: 10),
                        FloatingActionButton(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          heroTag: 1,
                          backgroundColor: CustomColors.btnBg,
                          onPressed: () => NavigatorService.pop(context),
                          child: ImageIcon(
                            AssetImage(
                              "assets/icons/list.png",
                            ),
                            size: 18,
                          ),
                        ),*/
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleDrawingCircle() {
    if (mounted) setState(() => _drawCircleEnabled = !_drawCircleEnabled);
    if (mounted) {
      setState(() {
        visible1 = false;
        s.clear();
      });
    }
  }

  void _toggleDrawing() {
    _clearPolygons();
    if (mounted) setState(() => _drawPolygonEnabled = !_drawPolygonEnabled);
  }

  Future<void> _onPanUpdate(DragUpdateDetails details) async {
    if (_clearDrawing) {
      if (mounted) {
        setState(() {
          _clearDrawing = false;
          _clearPolygons();
        });
      }
    }

    if (_drawPolygonEnabled) {
      final x = details.globalPosition.dx * (Platform.isAndroid ? MediaQuery.of(context).devicePixelRatio : 1);
      final y = details.globalPosition.dy * (Platform.isAndroid ? MediaQuery.of(context).devicePixelRatio : 1);

      final xCoordinate = x.round();
      final yCoordinate = y.round();

      if (_lastXCoordinate != null && _lastYCoordinate != null) {
        final distance = math.sqrt(math.pow(xCoordinate - _lastXCoordinate!, 2) + math.pow(yCoordinate - _lastYCoordinate!, 2));
        double distance1 = Platform.isAndroid ? 350 : 80;
        if (distance > distance1) return;
      }

      _lastXCoordinate = xCoordinate;
      _lastYCoordinate = yCoordinate;

      final screenCoordinate = ScreenCoordinate(x: xCoordinate, y: yCoordinate);

      final latLng = await _googleMapController!.getLatLng(screenCoordinate);

      try {
        _userPolyLinesLatLngList.add(latLng);

        _polyLines
          ..removeWhere((polyline) => polyline.polylineId.value == 'user_polyline')
          ..add(
            Polyline(
              polylineId: const PolylineId('user_polyline'),
              points: List<LatLng>.from(_userPolyLinesLatLngList),
              width: 4,
              color: isDark(context) ? CustomColors.navSelectedDark : CustomColors.navSelected,
            ),
          );
      } catch (e) {
        flutterLog("Error painting: $e");
      }
      if (mounted) setState(() {});
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (mounted) {
      setState(() {
        visible = true;
      });
    }
    _lastXCoordinate = null;
    _lastYCoordinate = null;

    if (_drawPolygonEnabled) {
      _polygons.removeWhere((polygon) => polygon.polygonId.value == 'user_polygon');

      _polygons.add(
        Polygon(
          polygonId: const PolygonId('user_polygon'),
          points: List<LatLng>.from(_userPolyLinesLatLngList),
          strokeWidth: 4,
          strokeColor: isDark(context) ? CustomColors.navSelectedDark : CustomColors.navSelected,
          fillColor: isDark(context) ? const Color.fromARGB(23, 147, 136, 205) : const Color.fromARGB(23, 100, 80, 170),
        ),
      );

      if (mounted) {
        setState(() {
          _clearDrawing = true;
        });
      }
    }
  }

  void _clearPolygons() {
    if (mounted) {
      setState(() {
        visible = false;
        _polyLines.clear();
        _polygons.clear();
        _userPolyLinesLatLngList.clear();
      });
    }
  }
}
