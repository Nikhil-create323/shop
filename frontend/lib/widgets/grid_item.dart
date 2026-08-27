// import 'package:dummy_apps/model/cart.dart';
// import 'package:dummy_apps/model/product.dart';
// import 'package:dummy_apps/screens/details.dart';
// import 'package:flutter/material.dart';

// class GridItem extends StatelessWidget {
//   var product;
//   GridItem({super.key, required this.product});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         child: InkWell(
//           onTap: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (ctx) => Details(product: product)),
//             );
//           },
//           child: Expanded(
//             child: Column(
//               children: [
//                 Image.network(product.imageUrl),
//                 SizedBox(height: 5),
//                 Text(product.title),
//                 SizedBox(height: 5),
//                 Text(product.price.toString()),
//                 SizedBox(height: 5),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
