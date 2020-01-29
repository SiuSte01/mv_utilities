from setuptools import setup

setup(name='mvUtil',
      description='Miscellaneous code for Champs products',
      url='unknown',
      use_scm_version=True,
      setup_requires=['setuptools_scm'],
      author='Stephen Siu',
      author_email='stephen.siu@lexisnexis.com',
		package_data={
			'': ['*.tab','*.txt','*.cfg','*.pm','*.sas','*.xlsm'],
			'projCode/src': ['dopatients.pl','multiBucket_ABCPM.pl','project_PAC.pl','sendemail.pl','*.sas'],
				'projCode/src/AdvisoryBoard': ['*'],
				'projCode/src/INA': ['*'],
				'projCode/src/INAA': ['*'],
				'projCode/src/Trending': ['*'],
		},
      packages=[
			'projCode/src',
				'projCode/src/AdvisoryBoard',
				'projCode/src/INA',
				'projCode/src/INAA',
				'projCode/src/Trending'
			#	'aggr/cloneAggr',
			#	'aggr/ina',
			#		'aggr/ina/filter',
			#		'aggr/ina/getInaEntityPcts',
			#		'aggr/ina/qaINA',
			#	'aggr/pxdx',
			#		'aggr/pxdx/buildAllCodesExact'
			],
      scripts=[
			'projCode/src/multiBucket.pl',
			'projCode/src/run_ABCPM.pl'
			],
      zip_safe=False)
