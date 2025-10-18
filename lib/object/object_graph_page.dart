import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

import 'object_manager.dart';
import '../object/object.dart' as app_object;
import '../types.dart'; // Assuming Types and getIconForType are here
import 'object_page.dart';

// --- GraphNode Class Definition ---
class GraphNode {
  final int id;
  final String name;
  final Types type;
  List<int> childrenIds;
  List<int> parentIds;
  Offset? position;
  int displayLayer;

  GraphNode({
    required this.id,
    required this.name,
    required this.type,
    this.childrenIds = const [],
    this.parentIds = const [],
    this.position,
    this.displayLayer = 0,
  });

  // ADD THIS GETTER
  String get formattedId {
    final x = id >> 8;      // Shift right by 8
    final y = id & 0xFF;    // Get the lower 8 bits
    return '$x.$y';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is GraphNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
// --- End of GraphNode Class Definition ---

class ObjectGraphPage extends StatefulWidget {
  const ObjectGraphPage({super.key});

  @override
  State<ObjectGraphPage> createState() => _ObjectGraphPageState();
}

class _ObjectGraphPageState extends State<ObjectGraphPage> {
  Map<int, GraphNode> _allNodesMap = {};
  Set<GraphNode> _displayNodes = {};
  int? _focusedNodeId;

  Offset _offset = Offset.zero;
  Offset? _dragStartPosition;
  static const double _panLimitPadding = 50.0;

  late ObjectManager _objectManager;

  static const double nodeWidth = 140.0;
  static const double nodeHeight = 60.0;
  static const double verticalSpacing = 40.0;
  static const double horizontalSpacing = 20.0;
  static const double layerHeight = nodeHeight + verticalSpacing;

  @override
  void initState() {
    super.initState();
    _objectManager = Provider.of<ObjectManager>(context, listen: false);
    _loadAndProcessGraphData();
    _objectManager.addListener(_onObjectManagerChanged);
  }

  @override
  void dispose() {
    _objectManager.removeListener(_onObjectManagerChanged);
    super.dispose();
  }

  void _onObjectManagerChanged() {
    _loadAndProcessGraphData();
  }

  // --- Data Processing ---
  void _loadAndProcessGraphData() {
    final objects = _objectManager.objects;
    _allNodesMap = _createGraphNodes(objects);
    _populateParentIds();
    _showRootView(); // Show root view after processing
  }

  Map<int, GraphNode> _createGraphNodes(List<app_object.Object> objects) {
    final tempNodesMap = <int, GraphNode>{};
    for (var obj in objects) {
      tempNodesMap[obj.id] = GraphNode(
        id: obj.id,
        name: obj.name,
        type: obj.type,
        childrenIds: obj.modules.map((e) => e.value).toList(),
      );
    }
    return tempNodesMap;
  }

  void _populateParentIds() {
    // Reset parentIds
    for (var node in _allNodesMap.values) {
      node.parentIds = [];
    }
    // Populate based on children
    for (var node in _allNodesMap.values) {
      for (var childId in node.childrenIds) {
        _allNodesMap[childId]?.parentIds.add(node.id);
      }
    }
  }

  // --- View Management ---
  void _showRootView() {
    _focusedNodeId = null;
    _displayNodes = _allNodesMap.values
        .where((node) => node.parentIds.isEmpty)
        .map((rootNode) => rootNode..displayLayer = 0)
        .toSet();
    _calculateAndSetNodePositions();
  }

  void _focusOnNode(int nodeId) {
    if (!_allNodesMap.containsKey(nodeId)) return;

    _focusedNodeId = nodeId;
    final focusedNode = _allNodesMap[nodeId]!;

    _displayNodes = _buildDisplayNodesForFocus(focusedNode);
    _calculateAndSetNodePositions();
    _centerViewOnNode(focusedNode);
  }

  Set<GraphNode> _buildDisplayNodesForFocus(GraphNode focusedNode) {
    final newDisplayNodes = <GraphNode>{};
    final visitedForLayout = <int>{};

    // Add focused node (Layer 0)
    focusedNode.displayLayer = 0;
    newDisplayNodes.add(focusedNode);
    visitedForLayout.add(focusedNode.id);

    // Add Parents (Layer -1)
    _addRelatedNodesToDisplay(
      sourceIds: focusedNode.parentIds,
      displayLayer: -1,
      displayNodesSet: newDisplayNodes,
      visitedSet: visitedForLayout,
    );

    // Add Children (Layer 1)
    final List<GraphNode> layer1Children = _addRelatedNodesToDisplay(
      sourceIds: focusedNode.childrenIds,
      displayLayer: 1,
      displayNodesSet: newDisplayNodes,
      visitedSet: visitedForLayout,
    );

    // Add Grandchildren (Layer 2)
    for (var layer1Child in layer1Children) {
      _addRelatedNodesToDisplay(
        sourceIds: layer1Child.childrenIds,
        displayLayer: 2,
        displayNodesSet: newDisplayNodes,
        visitedSet: visitedForLayout,
        // Ensure we don't re-add the focused node or its parents
        excludeIds: {focusedNode.id, ...focusedNode.parentIds},
      );
    }
    return newDisplayNodes;
  }

  List<GraphNode> _addRelatedNodesToDisplay({
    required List<int> sourceIds,
    required int displayLayer,
    required Set<GraphNode> displayNodesSet,
    required Set<int> visitedSet,
    Set<int> excludeIds = const {},
  }) {
    final List<GraphNode> addedNodes = [];
    for (var id in sourceIds) {
      if (_allNodesMap.containsKey(id) &&
          !visitedSet.contains(id) &&
          !excludeIds.contains(id)) {
        final relatedNode = _allNodesMap[id]!;
        relatedNode.displayLayer = displayLayer;
        displayNodesSet.add(relatedNode);
        addedNodes.add(relatedNode);
        visitedSet.add(id);
      }
    }
    return addedNodes;
  }

  void _centerViewOnNode(GraphNode node) {
    if (node.position != null && mounted) {
      final screenSize = MediaQuery.of(context).size;
      final appBarHeight = AppBar().preferredSize.height; // More reliable
      final paddingTop = MediaQuery.of(context).padding.top;

      final screenWidth = screenSize.width;
      final screenHeight = screenSize.height - appBarHeight - paddingTop;

      setState(() {
        _offset = Offset(
          screenWidth / 2 - node.position!.dx,
          screenHeight / 2 - node.position!.dy,
        );
      });
    }
  }

  // --- Node Positioning ---
  void _calculateAndSetNodePositions() {
    if (_displayNodes.isEmpty) {
      setState(() {}); // Trigger repaint even if empty to clear canvas
      return;
    }

    final Map<int, List<GraphNode>> nodesByLayer = {};
    for (var node in _displayNodes) {
      // Ensure all root nodes in home view are considered layer 0 for layout
      int layerKey = (_focusedNodeId == null) ? 0 : node.displayLayer;
      nodesByLayer.putIfAbsent(layerKey, () => []).add(node);
    }

    if (_focusedNodeId == null) {
      // --- Root View: Vertical Arrangement ---
      final roots = nodesByLayer[0] ?? [];
      if (roots.isNotEmpty) {
        // Calculate the total height required for vertical root nodes
        final double totalRootNodesHeight =
            roots.length * nodeHeight + (roots.length - 1) * verticalSpacing;

        // Start placing nodes from the top, centered horizontally
        // Offset by half the total height to center the block of roots vertically
        double currentY = -totalRootNodesHeight / 2 + nodeHeight / 2;
        final double centerX = 0; // Center horizontally for root view

        for (var rootNode in roots) {
          rootNode.position = Offset(
            centerX, // Centered horizontally
            currentY,
          );
          currentY += nodeHeight + verticalSpacing; // Move to the next Y position
        }
      }
    } else {
      // --- Focused View: Existing Horizontal Layered Arrangement ---
      double maxNodesInAnyLayer = 0;
      nodesByLayer.values.forEach((layerNodes) {
        maxNodesInAnyLayer = max(maxNodesInAnyLayer, layerNodes.length.toDouble());
      });

      final double contentWidthForWidestLayer = maxNodesInAnyLayer * nodeWidth +
          (maxNodesInAnyLayer > 0 ? (maxNodesInAnyLayer - 1) * horizontalSpacing : 0);

      final double initialXOffset = -contentWidthForWidestLayer / 2;

      _positionFocusedLayout(nodesByLayer, initialXOffset, contentWidthForWidestLayer);
    }
    setState(() {}); // Update UI with new positions
  }

  // _positionFocusedLayout and _positionNodesInLayer remain the same as your current version
  void _positionFocusedLayout(Map<int, List<GraphNode>> nodesByLayer, double overallInitialX, double totalContentWidth) {
    _positionNodesInLayer(
      nodes: nodesByLayer[-1] ?? [], // Parents
      yPosition: nodeHeight / 2,
      layerInitialXOffset: overallInitialX,
      totalContentWidthForCentering: totalContentWidth,
    );
    _positionNodesInLayer(
      nodes: nodesByLayer[0] ?? [], // Focused
      yPosition: layerHeight + nodeHeight / 2,
      layerInitialXOffset: overallInitialX,
      totalContentWidthForCentering: totalContentWidth,
    );
    _positionNodesInLayer(
      nodes: nodesByLayer[1] ?? [], // Children
      yPosition: 2 * layerHeight + nodeHeight / 2,
      layerInitialXOffset: overallInitialX,
      totalContentWidthForCentering: totalContentWidth,
    );
    _positionNodesInLayer(
      nodes: nodesByLayer[2] ?? [], // Grandchildren
      yPosition: 3 * layerHeight + nodeHeight / 2,
      layerInitialXOffset: overallInitialX,
      totalContentWidthForCentering: totalContentWidth,
    );
  }

  void _positionNodesInLayer({
    required List<GraphNode> nodes,
    required double yPosition,
    required double layerInitialXOffset,
    required double totalContentWidthForCentering,
  }) {
    if (nodes.isEmpty) return;
    final double currentLayerWidth = nodes.length * nodeWidth + (nodes.length - 1) * horizontalSpacing;
    final double centeringOffsetXForThisLayer = (totalContentWidthForCentering - currentLayerWidth) / 2;
    final double startX = layerInitialXOffset + centeringOffsetXForThisLayer;

    for (int i = 0; i < nodes.length; i++) {
      nodes[i].position = Offset(
        startX + i * (nodeWidth + horizontalSpacing) + nodeWidth / 2,
        yPosition,
      );
    }
  }


  // --- User Interactions ---
  void _onPanStart(DragStartDetails details) {
    _dragStartPosition = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartPosition == null) return;
    final delta = details.localPosition - _dragStartPosition!;

    setState(() {
      Offset newOffset = _offset + delta;

      final screenSize = MediaQuery.of(context).size;
      final appBarHeight = AppBar().preferredSize.height;
      final paddingTop = MediaQuery.of(context).padding.top;
      final screenWidth = screenSize.width;
      final screenHeight = screenSize.height - appBarHeight - paddingTop;

      Rect? graphBounds = _calculateCurrentGraphBounds();

      if (graphBounds != null) {
        double minOffsetX, maxOffsetX;
        double minOffsetY, maxOffsetY;

        // --- X-Axis Panning Limits ---
        if (graphBounds.width > screenWidth) {
          // Graph is WIDER than screen.
          // Allow panning until graph edges meet screen padding.
          maxOffsetX = _panLimitPadding - graphBounds.left;         // Stop rightward pan when graph's left edge hits screen's left padding
          minOffsetX = screenWidth - _panLimitPadding - graphBounds.right; // Stop leftward pan when graph's right edge hits screen's right padding
        } else {
          // Graph is NARROWER than screen.
          // Allow graph to move between screen paddings.
          minOffsetX = _panLimitPadding - graphBounds.left;         // Stop leftward pan when graph's left edge hits screen's left padding
          maxOffsetX = screenWidth - _panLimitPadding - graphBounds.right; // Stop rightward pan when graph's right edge hits screen's right padding
        }

        // --- Y-Axis Panning Limits ---
        if (graphBounds.height > screenHeight) {
          // Graph is TALLER than screen.
          maxOffsetY = _panLimitPadding - graphBounds.top;          // Stop downward pan when graph's top edge hits screen's top padding
          minOffsetY = screenHeight - _panLimitPadding - graphBounds.bottom; // Stop upward pan when graph's bottom edge hits screen's bottom padding
        } else {
          // Graph is SHORTER than screen.
          minOffsetY = _panLimitPadding - graphBounds.top;          // Stop upward pan when graph's top edge hits screen's top padding
          maxOffsetY = screenHeight - _panLimitPadding - graphBounds.bottom; // Stop downward pan when graph's bottom edge hits screen's bottom padding
        }

        // Ensure min is not greater than max (can happen if graph is much smaller than padding allows movement)
        if (minOffsetX > maxOffsetX) {
          minOffsetX = maxOffsetX = (minOffsetX + maxOffsetX) / 2; // Center it if range is invalid
        }
        if (minOffsetY > maxOffsetY) {
          minOffsetY = maxOffsetY = (minOffsetY + maxOffsetY) / 2;
        }

        newOffset = Offset(
          newOffset.dx.clamp(minOffsetX, maxOffsetX),
          newOffset.dy.clamp(minOffsetY, maxOffsetY),
        );

      } else {
        // Fallback: If no graphBounds, very basic limit.
        newOffset = Offset(
          newOffset.dx.clamp(-screenWidth + _panLimitPadding, screenWidth - _panLimitPadding),
          newOffset.dy.clamp(-screenHeight + _panLimitPadding, screenHeight - _panLimitPadding),
        );
      }

      _offset = newOffset;
      _dragStartPosition = details.localPosition;
    });
  }

  Rect? _calculateCurrentGraphBounds() {
    if (_displayNodes.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var node in _displayNodes) {
      if (node.position != null) {
        minX = min(minX, node.position!.dx - nodeWidth / 2);
        minY = min(minY, node.position!.dy - nodeHeight / 2);
        maxX = max(maxX, node.position!.dx + nodeWidth / 2);
        maxY = max(maxY, node.position!.dy + nodeHeight / 2);
      }
    }

    if (minX == double.infinity) return null; // No nodes with positions

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _onPanEnd(DragEndDetails details) {
    _dragStartPosition = null;
  }

  void _handleNodeTap(GraphNode tappedNode) {
    // If the tapped node is already focused (and is the main focused node at layer 0)
    if (_focusedNodeId == tappedNode.id && tappedNode.displayLayer == 0) {
      final app_object.Object? obj = _objectManager.objects
          .firstWhereOrNull((o) => o.id == tappedNode.id);
      if (obj != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ObjectPage(object: obj),
          ),
        );
      }
    } else {
      _focusOnNode(tappedNode.id);
    }
  }

  void _handleReloadGraph() {
    try {
      _objectManager.reloadObjects();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reloading data...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reloading data: $e')),
      );
    }
  }

  void _handleSaveGraph() {
    try {
      _objectManager.SaveAll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Graph'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Reload Graph',
            onPressed: _handleReloadGraph,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save Graph',
            onPressed: _handleSaveGraph,
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Show Root Nodes',
            onPressed: _showRootView,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Check if objectManager is initialized and has objects
    // This handles the initial state before _loadAndProcessGraphData completes
    bool hasObjects = _objectManager.objects.isNotEmpty;

    if (_allNodesMap.isEmpty && hasObjects) { // Data is available but not yet processed into _allNodesMap
      return const Center(child: CircularProgressIndicator());
    } else if (_allNodesMap.isEmpty && !hasObjects) { // No data from objectManager
      return const Center(child: Text('No objects to display. Try reloading.'));
    } else { // Nodes are processed, ready to display graph
      return GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: ClipRect(
          child: CustomPaint(
            painter: GraphPainter(
              nodes: _displayNodes,
              allNodesMap: _allNodesMap,
              offset: _offset,
              onNodeTap: _handleNodeTap,
              focusedNodeId: _focusedNodeId,
              nodeWidth: nodeWidth,
              nodeHeight: nodeHeight,
            ),
            size: Size.infinite,
          ),
        ),
      );
    }
  }
} // End of _ObjectGraphPageState

// --- GraphPainter ---
class GraphPainter extends CustomPainter {
  final Set<GraphNode> nodes; // Displayed nodes
  final Map<int, GraphNode> allNodesMap; // For looking up nodes not in current display set if needed
  final Offset offset;
  final Function(GraphNode) onNodeTap;
  final int? focusedNodeId;
  final double nodeWidth;
  final double nodeHeight;

  GraphPainter({
    required this.nodes,
    required this.allNodesMap,
    required this.offset,
    required this.onNodeTap,
    this.focusedNodeId,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  Color _getNodeFillColor(GraphNode node) {
    if (node.id == focusedNodeId && node.displayLayer == 0) return Colors.blue[100]!;
    if (node.displayLayer == -1) return Colors.green[50]!;
    if (node.displayLayer == 1) return Colors.orange[50]!;
    if (node.displayLayer == 2) return Colors.purple[50]!;
    return Colors.grey[200]!;
  }

  Paint _getNodeBorderPaint(GraphNode node) {
    bool isFocusedAndCenter = node.id == focusedNodeId && node.displayLayer == 0;
    return Paint()
      ..color = isFocusedAndCenter ? Colors.blueAccent : Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = isFocusedAndCenter ? 2.5 : 1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    final defaultEdgePaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1.5;

    // Paint for Focused (0) -> Child (1)
    final focusedToChildEdgePaint = Paint()
      ..color = Colors.blueAccent // Changed to blue
      ..strokeWidth = 2.0;

    // Paint for Parent (-1) -> Focused (0)
    final parentToFocusedEdgePaint = Paint()
      ..color = Colors.green // Matches parent node theme
      ..strokeWidth = 2.0;

    // Paint for Child (1) -> Grandchild (2)
    final childToGrandchildEdgePaint = Paint()
      ..color = Colors.orangeAccent // Matches child node theme, or choose distinct
      ..strokeWidth = 2.0;


    // Draw edges
    for (var node in nodes) {
      if (node.position == null) continue;

      for (var childId in node.childrenIds) {
        final GraphNode? childNode = nodes.firstWhereOrNull((n) => n.id == childId);

        if (childNode?.position != null) {
          Paint currentEdgePaint = defaultEdgePaint; // Start with default

          if (focusedNodeId != null) {
            // Case 1: Edge from Focused (0) to its direct Child (1)
            if (node.id == focusedNodeId && node.displayLayer == 0 && childNode!.displayLayer == 1) {
              currentEdgePaint = focusedToChildEdgePaint; // BLUE
            }
            // Case 2: Edge from a Parent (-1) to the Focused node (0)
            else if (node.displayLayer == -1 && childNode!.id == focusedNodeId && childNode.displayLayer == 0) {
              currentEdgePaint = parentToFocusedEdgePaint; // GREEN
            }
            // Case 3: Edge from a Child of focused (Layer 1) to a Grandchild (Layer 2)
            else if (node.displayLayer == 1 && childNode!.displayLayer == 2) {
              // Ensure 'node' (parent in this connection) is a direct child of the *actual* focused node
              if (allNodesMap[focusedNodeId]?.childrenIds.contains(node.id) ?? false) {
                currentEdgePaint = childToGrandchildEdgePaint; // ORANGE
              }
            }
          }

          canvas.drawLine(
            node.position!,
            childNode!.position!,
            currentEdgePaint,
          );
        }
      }
    }

    // Draw nodes (remains the same)
    for (var node in nodes) {
      if (node.position == null) continue;

      final nodeRect = Rect.fromCenter(
        center: node.position!,
        width: nodeWidth,
        height: nodeHeight,
      );
      final rrect = RRect.fromRectAndRadius(nodeRect, const Radius.circular(8.0));

      final fillPaint = Paint()..color = _getNodeFillColor(node);
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, _getNodeBorderPaint(node));

      final icon = getIconForType(node.type);
      final typeName = node.type.name;
      const textStyle = TextStyle(color: Colors.black87, fontSize: 12);

      final iconPainter = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
                fontSize: 18,
                fontFamily: icon.fontFamily,
                color: Colors.black54)),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(canvas, nodeRect.topLeft + const Offset(8, 6));

      final namePainter = TextPainter(
        text: TextSpan(
            text: node.name,
            style: textStyle.copyWith(
                fontWeight: FontWeight.bold, fontSize: 13)),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: nodeWidth - (8 + 18 + 6 + 8));
      namePainter.paint(canvas, nodeRect.topLeft + const Offset(8 + 18 + 6, 7));

      final typeAndIdText = '${node.formattedId} - $typeName';
      final typeAndIdPainter = TextPainter(
        text: TextSpan(text: typeAndIdText, style: textStyle.copyWith(fontSize: 11)),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: nodeWidth - 16);
      typeAndIdPainter.paint(
          canvas, nodeRect.topLeft + Offset(8, 8 + namePainter.height + 4));
    }
    canvas.restore();
  }

  // ... (hitTest and shouldRepaint methods remain the same)
  @override
  bool? hitTest(Offset position) {
    final transformedPosition = position - offset;
    for (var node in nodes.toList().reversed) {
      if (node.position != null) {
        final nodeRect = Rect.fromCenter(
          center: node.position!,
          width: nodeWidth,
          height: nodeHeight,
        );
        if (nodeRect.contains(transformedPosition)) {
          onNodeTap(node);
          return true;
        }
      }
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.offset != offset ||
        oldDelegate.focusedNodeId != focusedNodeId ||
        oldDelegate.allNodesMap != allNodesMap ||
        _didPositionsChange(oldDelegate.nodes, nodes);
  }

  bool _didPositionsChange(Set<GraphNode> oldNodes, Set<GraphNode> newNodes) {
    if (oldNodes.length != newNodes.length) return true;
    for (var newNode in newNodes) {
      final oldNode = oldNodes.firstWhereOrNull((n) => n.id == newNode.id);
      if (oldNode == null || oldNode.position != newNode.position || oldNode.displayLayer != newNode.displayLayer) {
        return true;
      }
    }
    return false;
  }
}

// Helper for shouldRepaint (already provided, but good to keep if used elsewhere)
// Not directly used in the _didPositionsChange above, but could be useful for other set comparisons.
bool setEquals<T>(Set<T>? a, Set<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  if (identical(a, b)) return true;
  for (final T value in a) {
    if (!b.contains(value)) return false;
  }
  return true;
}
