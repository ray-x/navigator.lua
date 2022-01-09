function curriedDot(vector1) {
  return function(vector2) {
    return vector1.reduce(
      (sum, element, index) => (sum += element * vector2[index]),
      0
    );
  };
}

const sumElements = curriedDot([1, 1, 1]);
console.log()
