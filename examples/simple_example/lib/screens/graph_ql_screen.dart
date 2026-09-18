import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// This screen uses the sample GraphQL server from this repository
/// https://github.com/nestjs/nest/tree/master/sample/12-graphql-schema-first
/// hosted at `localhost`. If you are using `datadog_gql_link` in conjunciton
/// with `datadog_tracking_http_client` remember to ignore your GraphQL endpoint
/// by providing it to [TrackingExtension.enableHttpTracking.ignoreUrlPatterns]
class GraphQlScreen extends StatefulWidget {
  const GraphQlScreen({super.key});

  @override
  State<GraphQlScreen> createState() => _GraphQlScreenState();
}

class _GraphQlScreenState extends State<GraphQlScreen> {
  final readCats = '''
query ReadCats() {
  cats{
    name
    age
  }
}
''';

  final addCat = '''
mutation CreateCat(\$name: String, \$age: Int){
  createCat(createCatInput: {name: \$name, age: \$age}) {
    name
    age
  }
}
''';

  final textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GraphQL')),
      body: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.white,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: const InputDecoration(labelText: 'Cat Name'),
                  ),
                ),
                Mutation(
                  options: MutationOptions(
                    document: gql(addCat),
                  ),
                  builder: (runMutation, result) {
                    return ElevatedButton(
                      onPressed: () => runMutation(
                        {
                          'name': textController.text,
                          'age': 1,
                        },
                      ),
                      child: const Text('Add Cat'),
                    );
                  },
                ),
              ],
            ),
            Query(
              options: QueryOptions(document: gql(readCats)),
              builder: ((result, {fetchMore, refetch}) {
                if (result.hasException) {
                  return Text(result.exception.toString());
                }

                if (result.isLoading) {
                  return const Text('Loading');
                }

                List? cats = result.data?['cats'];

                if (cats == null) {
                  return const Center(child: Text('No cats'));
                }

                return Column(
                  children: [for (final cat in cats) Text(cat['name'])],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
