// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';

class CustomCard extends StatelessWidget {
  final String image;
  final String text;
  final void Function()? onTap;

  const CustomCard({
    super.key,
    required this.image,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(8),
      child: Material(
        color: Colors.grey.shade200,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              FadeInImage.memoryNetwork(
                placeholder: kTransparentImage,
                image: image,
              ),
              Center(
                child: Text(
                  text,
                  style: theme.textTheme.headlineSmall,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
