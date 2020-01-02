from setuptools import setup

setup(name='mvUtil',
      description='Miscellaneous code for Champs products',
      url='unknown',
      use_scm_version=True,
      setup_requires=['setuptools_scm'],
      author='Stephen Siu',
      author_email='stephen.siu@lexisnexis.com',
		package_data={
			'': ['*.tab','*.txt','*.cfg','*.pm','*.xlsm'],
			'HGWorkFlow/src': ['*']
		},
      packages=[
			'HGWorkFlow/src'
			#	'aggr/cloneAggr',
			#	'aggr/ina',
			#		'aggr/ina/filter',
			#		'aggr/ina/getInaEntityPcts',
			#		'aggr/ina/qaINA',
			#	'aggr/pxdx',
			#		'aggr/pxdx/buildAllCodesExact'
			],
      scripts=[
			#'aggr/cloneAggr/cloneAggr.pl'
			],
      zip_safe=False)
