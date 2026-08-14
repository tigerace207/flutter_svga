part of 'player.dart';

class SVGAEasyPlayer extends StatefulWidget {
  final String? resUrl;
  final String? assetsName;
  final BoxFit fit;

  const SVGAEasyPlayer({
    super.key,
    this.resUrl,
    this.assetsName,
    this.fit = BoxFit.contain,
  });

  @override
  State<StatefulWidget> createState() {
    return _SVGAEasyPlayerState();
  }
}

class _SVGAEasyPlayerState extends State<SVGAEasyPlayer>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? animationController;

  @override
  void initState() {
    super.initState();
    animationController = SVGAAnimationController(vsync: this);
    _tryDecodeSvga();
  }

  @override
  void didUpdateWidget(covariant SVGAEasyPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resUrl != widget.resUrl ||
        oldWidget.assetsName != widget.assetsName) {
      _tryDecodeSvga();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (animationController == null) {
      return Container();
    }
    return SVGAImage(
      animationController!,
      fit: widget.fit,
    );
  }

  @override
  void dispose() {
    animationController?.dispose();
    animationController = null;
    super.dispose();
  }

  void _tryDecodeSvga() {
    Future<MovieEntity> decode;
    if (widget.resUrl != null) {
      decode = SVGAParser.shared.decodeFromURL(widget.resUrl!);
    } else if (widget.assetsName != null) {
      decode = SVGAParser.shared.decodeFromAssets(widget.assetsName!);
    } else {
      return;
    }

    decode.then((videoItem) {
      if (mounted && animationController != null) {
        animationController!
          ..videoItem = videoItem
          ..repeat();
      } else {
        videoItem.dispose();
      }
    }).catchError(
      (e, stack) {
        // FlutterError.reportError(
        //   FlutterErrorDetails(
        //     exception: e,
        //     stack: stack,
        //     library: 'SVGAEasyPlayer',
        //     context: ErrorDescription('during _tryDecodeSvga'),
        //     informationCollector: () => [
        //       if (widget.resUrl != null)
        //         StringProperty('resUrl', widget.resUrl),
        //       if (widget.assetsName != null)
        //         StringProperty('assetsName', widget.assetsName),
        //     ],
        //   ),
        // );
      },
    );
  }
}
