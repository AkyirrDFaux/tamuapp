import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'new_object_page.dart';
import 'object_manager.dart';
import 'object.dart';
import 'dart:math';

import 'object_page.dart';

class Node {
  final int id;
  final String name;
  final List<int> childrenIds;
  Offset? position;
  int level;
  int rootId; // Add rootId

  Node({
    required this.id,
    required this.name,
    this.childrenIds = const [],
    this.position,
    this.level = 0,
    this.rootId = -1, // Initialize with a default value
  });
}

Map<int, Node> generateGraphDataFromObjects(List<Object> objects) {
  Map<int, Node> treeData = {};

  for (var obj in objects) {
    treeData[obj.id] = Node(
      id: obj.id,
      name: obj.name,
      childrenIds: obj.modules.map((e) => e.value).toList(),
    );
  }
  return treeData;
}

class ObjectGraphPage extends StatefulWidget {
  const ObjectGraphPage({super.key});

  @override
  State<ObjectGraphPage> createState() => _ObjectGraphPageState();
}

class _ObjectGraphPageState extends State<ObjectGraphPage> {
  late Map<int, Node> graphData =
  generateGraphDataFromObjects(Provider.of<ObjectManager>(context, listen: false).objects);
  Size? _parentSize;
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  late Offset _initialFocalPoint;
  late Offset _initialOffset;
  late double _initialScale;
  late ObjectManager _objectManager;

  @override
  void initState() {
    super.initState();
    // Initialize graphData here
    _objectManager = Provider.of<ObjectManager>(context, listen: false);
    graphData = generateGraphDataFromObjects(_objectManager.objects);
    // Add listener to ObjectManager
    _objectManager.addListener(_onObjectManagerChanged);
  }

  @override
  void dispose() {
    // Remove listener using the stored reference
    _objectManager.removeListener(_onObjectManagerChanged);
    super.dispose();
  }

  // Listener callback
  void _onObjectManagerChanged() {
    // Rebuild the graph when ObjectManager changes
    setState(() {
      graphData = generateGraphDataFromObjects(
          Provider.of<ObjectManager>(context, listen: false).objects);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_parentSize != null) {
      _calculateNodePositions();
    }
  }

  void _calculateNodePositions() {
    if (_parentSize == null) {
      return;
    }

    // Find root nodes (nodes with no parents)
    List<Node> rootNodes = graphData.values.where((node) {
      return !graphData.values
          .any((other) => other.childrenIds.contains(node.id));
    }).toList();

    // Assign root IDs and levels using DFS
    for (Node root in rootNodes) {
      _assignRootAndLevelsDFS(root, root.id, 0, {});
    }

    // Group nodes by root
    Map<int, List<Node>> nodesByRoot = {};
    for (var node in graphData.values) {
      nodesByRoot.putIfAbsent(node.rootId, () => []).add(node);
    }

    // Calculate positions for each root group
    const double nodeWidth = 100.0;
    const double nodeHeight = 50.0;
    const double verticalSpacing = 100.0;
    const double horizontalSpacing = 50.0;
    double currentY = verticalSpacing;

    for (var rootId in nodesByRoot.keys) {
      List<Node> nodesInRoot = nodesByRoot[rootId]!;

      // Group nodes by level within the root group
      Map<int, List<Node>> nodesByLevel = {};
      for (var node in nodesInRoot) {
        nodesByLevel.putIfAbsent(node.level, () => []).add(node);
      }

      // Calculate the maximum width needed for this root group
      double maxLevelWidth = 0;
      for (var level in nodesByLevel.keys) {
        List<Node> nodes = nodesByLevel[level]!;
        double levelWidth = nodes.length * nodeWidth + (nodes.length - 1) * horizontalSpacing;
        maxLevelWidth = max(maxLevelWidth, levelWidth);
      }

      // Calculate positions for each level within the root group
      double centerX = _parentSize!.width / 2;
      double startY = currentY;

      for (var level in nodesByLevel.keys.toList()..sort()) {
        List<Node> nodes = nodesByLevel[level]!;
        double levelWidth = nodes.length * nodeWidth + (nodes.length - 1) * horizontalSpacing;
        double levelStartX = centerX - levelWidth / 2;

        for (int i = 0; i < nodes.length; i++) {
          nodes[i].position = Offset(levelStartX + i * (nodeWidth + horizontalSpacing) + nodeWidth / 2, startY + nodeHeight / 2);
        }
        startY += verticalSpacing + nodeHeight;
      }
      currentY = startY + verticalSpacing; // Add extra spacing between root groups
    }
  }

  void _assignRootAndLevelsDFS(Node node, int rootId, int level, Set<int> visited) {
    if (visited.contains(node.id)) {
      return;
    }
    visited.add(node.id);

    node.rootId = rootId;
    node.level = level;

    for (int childId in node.childrenIds) {
      Node? child = graphData[childId];
      if (child != null) {
        Set<int> childVisited = Set.from(visited);
        _assignRootAndLevelsDFS(child, rootId, level + 1, childVisited);
      }
    }
  }

  void _handleNodeTap(Node tappedNode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ObjectPage(
            object: ObjectManager().objects.firstWhere((Object obj) => obj.id == tappedNode.id)),
      ),
    );
  }

  // ... (other methods from your original file)
  void _onScaleStart(ScaleStartDetails details) {
    _initialFocalPoint = details.focalPoint;
    _initialOffset = _offset;
    _initialScale = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = _initialScale * details.scale;
      _scale = _scale.clamp(0.2, 1.0);

      final newFocalPoint = details.focalPoint;
      final focalPointDelta = newFocalPoint - _initialFocalPoint;
      _offset = _initialOffset + focalPointDelta / _scale;
    });
  }

  void _onTapDown(TapDownDetails details) {
    final tapPosition = details.localPosition;
    final transformedTapPosition = (tapPosition/ _scale - _offset) ;

    // Check if the tap is within a node
    for (Node node in graphData.values) {
      if (node.position != null) {
        // Apply the inverse transformation to the node position
        final transformedNodePosition = node.position!;
        final rect = Rect.fromCenter(
            center: transformedNodePosition, width: 100, height: 50);
        if (rect.contains(transformedTapPosition)) {
          _handleNodeTap(node);
          break; // Exit the loop after handling the tap
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Graph'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showNewObjectDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // Access the ObjectManager and call the reload method
              final manager = Provider.of<ObjectManager>(context, listen: false);
              manager.SaveAll();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Access the ObjectManager and call the reload method
              final manager = Provider.of<ObjectManager>(context, listen: false);
              manager.reloadObjects();
            },
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        _parentSize = constraints.biggest;
        if (graphData.isNotEmpty && _parentSize != null) {
          _calculateNodePositions();
        }
        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onTapDown: _onTapDown,
          child: Center(
            child: ClipRect(
              child: CustomPaint(
                painter: GraphPainter(graphData, _offset, _scale),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class GraphPainter extends CustomPainter {
  final Map<int, Node> graphData;
  final Offset offset;
  final double scale;

  GraphPainter(this.graphData, this.offset, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    canvas.translate(offset.dx, offset.dy);

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2 / scale;

    // Draw edges
    for (Node node in graphData.values) {
      if (node.position != null) {
        for (int childId in node.childrenIds) {
          Node? child = graphData[childId];
          if (child != null && child.position != null) {
            // Calculate the bottom center of the parent node
            Offset parentBottomCenter = Offset(node.position!.dx, node.position!.dy + 25);
            // Calculate the top center of the child node
            Offset childTopCenter = Offset(child.position!.dx, child.position!.dy - 25);
            canvas.drawLine(parentBottomCenter, childTopCenter, paint);
          }
        }
      }
    }

    // Draw nodes
    for (Node node in graphData.values) {
      if (node.position != null) {
        final rect = Rect.fromCenter(
            center: node.position!, width: 100, height: 50);
        canvas.drawRect(rect, paint..color = Colors.blue);

        final textPainter = TextPainter(
          text: TextSpan(
              text: "${node.name}\n${node.id}",
              style: TextStyle(color: Colors.white, fontSize: 12)),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
            canvas,
            Offset(node.position!.dx - textPainter.width / 2,
                node.position!.dy - textPainter.height / 2));
      }
    }
    canvas.restore();
  }

  @override
  bool hitTest(Offset position) {
    return true;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}