function moduleServiceMdns(location, value, errors) {
	return value;
}

return {
	validate: function(location, value, errors) {
		return moduleServiceMdns(location, value, errors);
	}
};
