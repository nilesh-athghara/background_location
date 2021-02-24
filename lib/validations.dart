String nullTextValidate(String val) {
  {
    if (val.isEmpty || val == null) {
      return 'Required';
    }
    return null;
  }
}
